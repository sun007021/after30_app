import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain(iOS)/Keystore(Android) 접근을 추상화한다. 테스트에서는 메모리
/// 기반 가짜 구현으로 교체할 수 있다(플랫폼 채널을 직접 목킹하지 않아도
/// 되게 하기 위함).
abstract class SecureStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureStorageAdapter implements SecureStorageAdapter {
  const _FlutterSecureStorageAdapter();

  // 리뷰 M1③: 기기 잠금 중(예: "복용 완료" 알림 액션이 백그라운드에서 실행될
  // 때)에도 읽을 수 있도록 `first_unlock_this_device`를 쓴다. 기본값
  // (`unlocked`류)은 잠금 상태에서 접근이 막혀 M1이 다루는 "보안 저장소
  // 예외" 상황을 오히려 흔하게 만든다. `..._this_device`는 iCloud 키체인
  // 백업/기기 간 이전 대상에서도 제외돼, 토큰이 다른 기기로 복원되는 것도
  // 막는다.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static const _storage = FlutterSecureStorage(iOptions: _iosOptions);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 로그인 토큰 저장소.
///
/// **D8(plan §2)**: 예전에는 SharedPreferences(iOS에서는 NSUserDefaults
/// 평문)에 저장했지만, 이제 Keychain/Keystore(`flutter_secure_storage`)로
/// 옮긴다.
///
/// - 기존 사용자는 SharedPreferences에 남아있던 토큰을 최초 1회 Keychain/
///   Keystore로 옮기고 SharedPreferences 값은 지운다 — Android 사용자는
///   업그레이드 후에도 로그인이 유지돼야 한다. **레거시 토큰이 있으면
///   "설치됨" 마커 유무와 무관하게 항상 먼저 마이그레이션한다**(리뷰 B1) —
///   예전 버전은 이 마커 자체를 쓴 적이 없어서, 마커 존재 여부만으로
///   "재설치냐 업그레이드냐"를 구분할 수 없다.
/// - iOS는 앱을 삭제해도 Keychain 값이 남는다. 레거시 토큰도 없고 마커도
///   없는 첫 실행에만(=업그레이드가 아니라 재설치/최초 설치가 확실한
///   경우) 잔존 Keychain 토큰을 지운다. Android는 이 정리를 적용하지
///   않는다.
class TokenStore {
  TokenStore._();

  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kAccessExpiresInKey = 'access_expires_in';
  static const _kRefreshExpiresInKey = 'refresh_expires_in';

  /// SharedPreferences 쪽에 남기는 "설치됨" 표시 키.
  static const _kInstalledMarkerKey = 'token_store_installed_marker';

  static SecureStorageAdapter _secure = const _FlutterSecureStorageAdapter();

  /// 테스트 전용: 실제 Keychain 대신 메모리 기반 가짜 저장소를 주입한다.
  @visibleForTesting
  static void debugOverrideSecureStorage(SecureStorageAdapter adapter) {
    _secure = adapter;
    _migration = null;
  }

  /// 테스트 전용: 실제 Keychain 어댑터와 마이그레이션 상태를 되돌린다.
  @visibleForTesting
  static void debugReset() {
    _secure = const _FlutterSecureStorageAdapter();
    _migration = null;
  }

  /// 마이그레이션은 앱 생애주기당 정확히 한 번만 실행돼야 한다(리뷰
  /// B1-a). 예전에는 `_migrated = true`를 작업 시작 "전"에 표시해서,
  /// `restore()`/FCM 토큰 갱신/알림 액션 API 호출처럼 시작 시점에 동시에
  /// 여러 호출자가 `TokenStore`를 건드리면 마이그레이션이 끝나기도 전에
  /// 빈 저장소를 읽어가는 경합이 있었다. `Future`를 캐싱해 모든 동시
  /// 호출자가 "같은 한 번의 실행"을 기다리게 하고, 실패하면 다음 호출에서
  /// 다시 시도할 수 있게 캐시를 비운다.
  static Future<void>? _migration;

  static Future<void> _ensureMigrated() {
    return _migration ??= _runMigration().catchError((Object e) {
      _migration = null; // 실패하면 다음 호출에서 재시도할 수 있게 한다.
      throw e;
    });
  }

  static Future<void> _runMigration() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyInstalled = prefs.getBool(_kInstalledMarkerKey) ?? false;
    final legacyAccess = prefs.getString(_kAccessTokenKey);

    if (legacyAccess != null) {
      // 리뷰 B1: 마커 유무와 무관하게 레거시 토큰이 있으면 항상 먼저
      // 옮긴다. 예전 버전은 마커를 쓴 적이 없어서, "마커가 없다 = 재설치"
      // 로 단정하면 업그레이드한 기존 사용자를 매번 로그아웃시키고, 그
      // 다음 실행에서는 방금 새로 로그인한 토큰을 예전 값으로 덮어써
      // 버렸다(계정이 조용히 바뀌는 문제).
      await _secure.write(_kAccessTokenKey, legacyAccess);
      await _secure.write(
        _kRefreshTokenKey,
        prefs.getString(_kRefreshTokenKey) ?? '',
      );
      await _secure.write(
        _kAccessExpiresInKey,
        (prefs.getInt(_kAccessExpiresInKey) ?? 0).toString(),
      );
      await _secure.write(
        _kRefreshExpiresInKey,
        (prefs.getInt(_kRefreshExpiresInKey) ?? 0).toString(),
      );
      await prefs.remove(_kAccessTokenKey);
      await prefs.remove(_kRefreshTokenKey);
      await prefs.remove(_kAccessExpiresInKey);
      await prefs.remove(_kRefreshExpiresInKey);
    } else if (!alreadyInstalled && defaultTargetPlatform == TargetPlatform.iOS) {
      // 레거시 토큰도 없고 마커도 없다 = 업그레이드가 아니라 진짜 재설치/
      // 최초 설치다. iOS는 앱 삭제 후에도 Keychain이 남으므로 잔존 값을
      // 지운다.
      await _secure.delete(_kAccessTokenKey);
      await _secure.delete(_kRefreshTokenKey);
      await _secure.delete(_kAccessExpiresInKey);
      await _secure.delete(_kRefreshExpiresInKey);
    }

    if (!alreadyInstalled) {
      await prefs.setBool(_kInstalledMarkerKey, true);
    }
  }

  /// 로그인 성공 직후 호출된다. 실패하면 그대로 다시 던져 로그인 화면이
  /// 오류를 보여줄 수 있게 한다(리뷰 M1② — 저장 실패를 조용히 삼키면
  /// 사용자가 로그인된 줄 알고 있다가 다음 요청에서야 401을 만난다).
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int accessExpiresIn,
    required int refreshExpiresIn,
  }) async {
    await _ensureMigrated();
    await _secure.write(_kAccessTokenKey, accessToken);
    await _secure.write(_kRefreshTokenKey, refreshToken);
    await _secure.write(_kAccessExpiresInKey, accessExpiresIn.toString());
    await _secure.write(_kRefreshExpiresInKey, refreshExpiresIn.toString());
  }

  /// 리뷰 M1②: 보안 저장소 접근이 실패하면(기기 잠금 중 Keychain 접근,
  /// Android Auto Backup으로 복원된 Keystore 키 불일치, 플러그인 없는 테스트
  /// 환경 등) 예외를 던지는 대신 "로그아웃 상태"로 취급해 null을 반환한다.
  /// 호출부(ApiClient 등)가 이 값을 던지지 않는다는 전제로 짜여 있으므로,
  /// 여기서 삼키지 않으면 요청이 영원히 멈춘다(M1①).
  static Future<String?> getAccessToken() async {
    try {
      await _ensureMigrated();
      return await _secure.read(_kAccessTokenKey);
    } catch (e) {
      debugPrint('TokenStore: 액세스 토큰 읽기 실패: $e');
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      await _ensureMigrated();
      return await _secure.read(_kRefreshTokenKey);
    } catch (e) {
      debugPrint('TokenStore: 리프레시 토큰 읽기 실패: $e');
      return null;
    }
  }

  /// 로그아웃/탈퇴 시 호출된다. 최선을 다해 지우되(best-effort), 저장소
  /// 접근 자체가 실패해도 로그아웃 흐름을 막지 않는다.
  static Future<void> clear() async {
    try {
      await _ensureMigrated();
      await _secure.delete(_kAccessTokenKey);
      await _secure.delete(_kRefreshTokenKey);
      await _secure.delete(_kAccessExpiresInKey);
      await _secure.delete(_kRefreshExpiresInKey);
    } catch (e) {
      debugPrint('TokenStore: 토큰 삭제 실패(무시): $e');
    }
  }
}
