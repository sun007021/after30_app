import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/token_store.dart';

import '../../support/fake_secure_storage.dart';

/// 항상 예외를 던지는 가짜 보안 저장소(리뷰 M1② 회귀 테스트용).
class _ThrowingSecureStorage implements SecureStorageAdapter {
  @override
  Future<String?> read(String key) async => throw Exception('keystore broken');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('keystore broken');

  @override
  Future<void> delete(String key) async => throw Exception('keystore broken');
}

/// 마이그레이션 도중 동시 호출이 경합하는지 확인하기 위해 쓰기를 일부러
/// 느리게 만드는 가짜 저장소(리뷰 B1-a 회귀 테스트용).
class _SlowSecureStorage extends FakeSecureStorage {
  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    TokenStore.debugOverrideSecureStorage(fakeStorage);
  });

  tearDown(() {
    TokenStore.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  test('saveTokens/getAccessToken/getRefreshToken/clear가 Keychain에 저장·조회된다', () async {
    SharedPreferences.setMockInitialValues({
      // 이미 설치된 상태(첫 실행 마이그레이션/정리 로직을 건너뛰기 위함)
      'token_store_installed_marker': true,
    });

    await TokenStore.saveTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      accessExpiresIn: 3600,
      refreshExpiresIn: 86400,
    );

    expect(await TokenStore.getAccessToken(), 'access-1');
    expect(await TokenStore.getRefreshToken(), 'refresh-1');
    expect(fakeStorage.store['access_token'], 'access-1');

    await TokenStore.clear();
    expect(await TokenStore.getAccessToken(), isNull);
    expect(await TokenStore.getRefreshToken(), isNull);
  });

  test('업그레이드 사용자: SharedPreferences에 남은 평문 토큰을 Keychain으로 1회 마이그레이션한다', () async {
    // "설치됨" 마커가 있는 상태(정리 로직을 이미 한 번 거쳤다는 뜻)에서
    // SharedPreferences에 예전(D8 이전) 평문 토큰이 남아있으면 업그레이드
    // 시나리오로 취급해 Keychain으로 옮긴다.
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
      'access_token': 'legacy-access',
      'refresh_token': 'legacy-refresh',
      'access_expires_in': 3600,
      'refresh_expires_in': 86400,
    });

    final accessToken = await TokenStore.getAccessToken();
    expect(accessToken, 'legacy-access');
    expect(fakeStorage.store['access_token'], 'legacy-access');
    expect(fakeStorage.store['refresh_token'], 'legacy-refresh');

    // SharedPreferences 쪽 평문 값은 지워졌어야 한다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test('iOS 재설치: "설치됨" 마커가 없으면 잔존 Keychain 토큰을 지운다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fakeStorage.store['access_token'] = 'leftover-from-previous-install';
    fakeStorage.store['refresh_token'] = 'leftover-refresh';
    SharedPreferences.setMockInitialValues({});

    final accessToken = await TokenStore.getAccessToken();

    expect(accessToken, isNull);
    expect(fakeStorage.store.containsKey('access_token'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('token_store_installed_marker'), isTrue);
  });

  test('Android는 "설치됨" 마커가 없어도 Keystore 값을 지우지 않는다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    fakeStorage.store['access_token'] = 'android-existing-token';
    SharedPreferences.setMockInitialValues({});

    final accessToken = await TokenStore.getAccessToken();

    expect(accessToken, 'android-existing-token');
  });

  group('리뷰 B1: 실제 업그레이드(마커 없음 + 레거시 토큰 있음)', () {
    // 예전 버전은 "설치됨" 마커 자체를 쓴 적이 없다. 마커 유무만으로
    // "재설치냐 업그레이드냐"를 구분하면, 마커가 없는 이 실제 업그레이드
    // 상황에서 매번 재설치로 오판해 로그인 토큰을 지워버렸다(모든 기존
    // 사용자가 로그아웃당함).
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('$platform: 마커 없이 업그레이드해도 로그인이 유지된다', () async {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({
          'access_token': 'legacy-access',
          'refresh_token': 'legacy-refresh',
          'access_expires_in': 3600,
          'refresh_expires_in': 86400,
        });

        final refresh = await TokenStore.getRefreshToken();

        expect(refresh, 'legacy-refresh');
        expect(fakeStorage.store['access_token'], 'legacy-access');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), isNull);
        expect(prefs.getBool('token_store_installed_marker'), isTrue);
      });
    }

    test('두 번째 실행에서 방금 로그인한 토큰을 예전 값으로 덮어쓰지 않는다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy-access-userA',
        'refresh_token': 'legacy-refresh-userA',
        'access_expires_in': 3600,
        'refresh_expires_in': 86400,
      });

      // 1차 실행: 마이그레이션이 한 번 일어나고, 이후 사용자가 새로
      // 로그인한다(예: 다른 계정으로 로그인).
      await TokenStore.getRefreshToken();
      await TokenStore.saveTokens(
        accessToken: 'fresh-access-userB',
        refreshToken: 'fresh-refresh-userB',
        accessExpiresIn: 1,
        refreshExpiresIn: 1,
      );

      // 2차 실행(새 프로세스를 흉내냄): 마이그레이션 상태만 초기화하고
      // 같은 Keychain/Keystore, 같은 SharedPreferences를 그대로 쓴다.
      // SharedPreferences 쪽 레거시 값은 1차 실행에서 이미 지워졌으므로
      // 다시 마이그레이션할 것이 없어야 한다.
      TokenStore.debugOverrideSecureStorage(fakeStorage);
      final access = await TokenStore.getAccessToken();

      expect(access, 'fresh-access-userB');
    });
  });

  test('리뷰 B1-a: 마이그레이션 도중 동시에 호출해도 경합 없이 같은 결과를 본다', () async {
    final slow = _SlowSecureStorage();
    TokenStore.debugOverrideSecureStorage(slow);
    SharedPreferences.setMockInitialValues({
      'access_token': 'legacy-access',
      'refresh_token': 'legacy-refresh',
      'access_expires_in': 1,
      'refresh_expires_in': 1,
    });

    // 예전 구현은 `_migrated = true`를 마이그레이션 작업 "시작 전"에
    // 표시해서, 동시에 들어온 두 번째 호출이 아직 끝나지 않은 마이그레이션
    // 결과(빈 저장소)를 읽어갈 수 있었다.
    final results = await Future.wait([
      TokenStore.getAccessToken(),
      TokenStore.getAccessToken(),
    ]);

    expect(results, ['legacy-access', 'legacy-access']);
  });

  group('리뷰 M1②: 보안 저장소 접근이 실패해도 예외를 밖으로 던지지 않는다', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'token_store_installed_marker': true,
      });
      TokenStore.debugOverrideSecureStorage(_ThrowingSecureStorage());
    });

    test('getAccessToken은 null을 반환한다(로그아웃 상태로 취급)', () async {
      expect(await TokenStore.getAccessToken(), isNull);
    });

    test('getRefreshToken은 null을 반환한다', () async {
      expect(await TokenStore.getRefreshToken(), isNull);
    });

    test('clear는 예외를 삼킨다(best-effort)', () async {
      await expectLater(TokenStore.clear(), completes);
    });

    test('saveTokens는 예외를 다시 던진다(로그인 화면이 실패를 알 수 있게)', () async {
      await expectLater(
        TokenStore.saveTokens(
          accessToken: 'a',
          refreshToken: 'r',
          accessExpiresIn: 1,
          refreshExpiresIn: 1,
        ),
        throwsException,
      );
    });
  });
}
