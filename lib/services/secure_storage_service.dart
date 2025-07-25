import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // 토큰 저장
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required int refreshExpiresIn,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'expires_in', value: expiresIn.toString());
    await _storage.write(
      key: 'refresh_expires_in',
      value: refreshExpiresIn.toString(),
    );
  }

  // 토큰 불러오기
  static Future<Map<String, String?>> getTokens() async {
    final accessToken = await _storage.read(key: 'access_token');
    final refreshToken = await _storage.read(key: 'refresh_token');
    final expiresIn = await _storage.read(key: 'expires_in');
    final refreshExpiresIn = await _storage.read(key: 'refresh_expires_in');
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'refresh_expires_in': refreshExpiresIn,
    };
  }

  // 토큰 삭제
  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'expires_in');
    await _storage.delete(key: 'refresh_expires_in');
  }

  // 유저정보 저장
  static Future<void> saveUser({
    required int userId,
    required String userName,
  }) async {
    await _storage.write(key: 'user_id', value: userId.toString());
    await _storage.write(key: 'user_name', value: userName);
  }

  // 유저정보 불러오기
  static Future<Map<String, String?>> getUser() async {
    final userId = await _storage.read(key: 'user_id');
    final userName = await _storage.read(key: 'user_name');
    return {'user_id': userId, 'user_name': userName};
  }

  // 유저정보 삭제
  static Future<void> clearUser() async {
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_name');
  }

  // 전체 삭제
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
