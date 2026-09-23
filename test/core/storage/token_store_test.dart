import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/token_store.dart';

import 'fake_secure_storage.dart';

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
}
