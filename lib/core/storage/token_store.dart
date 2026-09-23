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

  static const _storage = FlutterSecureStorage();

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
///   업그레이드 후에도 로그인이 유지돼야 한다.
/// - iOS는 앱을 삭제해도 Keychain 값이 남는다. 재설치를 감지하기 위해
///   SharedPreferences에 "설치됨" 표시를 두고, 그 표시가 없는 첫 실행에는
///   (재설치로 간주) 잔존 Keychain 토큰을 지운다. Android는 이 정리를
///   적용하지 않는다(Keystore는 앱 삭제 시 함께 사라지므로 해당 없음 —
///   실수로 정상 토큰을 지우지 않도록 플랫폼을 명시적으로 확인한다).
class TokenStore {
  TokenStore._();

  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kAccessExpiresInKey = 'access_expires_in';
  static const _kRefreshExpiresInKey = 'refresh_expires_in';

  /// SharedPreferences 쪽에 남기는 "설치됨" 표시 키. Keychain에는 앱 삭제와
  /// 무관하게 값이 남으므로, 이 표시가 없다는 것은 "SharedPreferences가
  /// 방금 새로 생겼다" = 재설치(또는 최초 설치)라는 뜻이다.
  static const _kInstalledMarkerKey = 'token_store_installed_marker';

  static SecureStorageAdapter _secure = const _FlutterSecureStorageAdapter();
  static bool _migrated = false;

  /// 테스트 전용: 실제 Keychain 대신 메모리 기반 가짜 저장소를 주입한다.
  @visibleForTesting
  static void debugOverrideSecureStorage(SecureStorageAdapter adapter) {
    _secure = adapter;
    _migrated = false;
  }

  /// 테스트 전용: 실제 Keychain 어댑터와 마이그레이션 상태를 되돌린다.
  @visibleForTesting
  static void debugReset() {
    _secure = const _FlutterSecureStorageAdapter();
    _migrated = false;
  }

  /// 재설치 감지 + SharedPreferences → Keychain/Keystore 1회 마이그레이션을
  /// 수행한다. 모든 공개 메서드가 시작할 때 호출해 지연 초기화한다.
  static Future<void> _ensureMigrated() async {
    if (_migrated) return;
    _migrated = true;

    final prefs = await SharedPreferences.getInstance();
    final alreadyInstalled = prefs.getBool(_kInstalledMarkerKey) ?? false;

    if (!alreadyInstalled) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // 재설치(또는 최초 설치) — iOS에서 앱 삭제 후에도 남아있을 수 있는
        // 잔존 Keychain 토큰을 정리한다.
        await _secure.delete(_kAccessTokenKey);
        await _secure.delete(_kRefreshTokenKey);
        await _secure.delete(_kAccessExpiresInKey);
        await _secure.delete(_kRefreshExpiresInKey);
      }
      await prefs.setBool(_kInstalledMarkerKey, true);
      return;
    }

    // 이미 설치된 상태 = 업그레이드 시나리오. SharedPreferences에 예전
    // 토큰이 남아있으면 Keychain/Keystore로 1회 옮기고 평문 값은 지운다.
    final legacyAccess = prefs.getString(_kAccessTokenKey);
    if (legacyAccess == null) return;

    final legacyRefresh = prefs.getString(_kRefreshTokenKey) ?? '';
    final legacyAccessExp = prefs.getInt(_kAccessExpiresInKey) ?? 0;
    final legacyRefreshExp = prefs.getInt(_kRefreshExpiresInKey) ?? 0;

    await _secure.write(_kAccessTokenKey, legacyAccess);
    await _secure.write(_kRefreshTokenKey, legacyRefresh);
    await _secure.write(_kAccessExpiresInKey, legacyAccessExp.toString());
    await _secure.write(_kRefreshExpiresInKey, legacyRefreshExp.toString());

    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kAccessExpiresInKey);
    await prefs.remove(_kRefreshExpiresInKey);
  }

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

  static Future<String?> getAccessToken() async {
    await _ensureMigrated();
    return _secure.read(_kAccessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    await _ensureMigrated();
    return _secure.read(_kRefreshTokenKey);
  }

  static Future<void> clear() async {
    await _ensureMigrated();
    await _secure.delete(_kAccessTokenKey);
    await _secure.delete(_kRefreshTokenKey);
    await _secure.delete(_kAccessExpiresInKey);
    await _secure.delete(_kRefreshExpiresInKey);
  }
}
