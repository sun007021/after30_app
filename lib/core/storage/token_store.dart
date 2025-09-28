import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  static const _kAccessExpiresInKey = 'access_expires_in';
  static const _kRefreshExpiresInKey = 'refresh_expires_in';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int accessExpiresIn,
    required int refreshExpiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, accessToken);
    await prefs.setString(_kRefreshTokenKey, refreshToken);
    await prefs.setInt(_kAccessExpiresInKey, accessExpiresIn);
    await prefs.setInt(_kRefreshExpiresInKey, refreshExpiresIn);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshTokenKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kAccessExpiresInKey);
    await prefs.remove(_kRefreshExpiresInKey);
  }
}
