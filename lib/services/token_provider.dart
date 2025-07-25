import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class TokenProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  int? _expiresIn;
  int? _refreshExpiresIn;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get expiresIn => _expiresIn;
  int? get refreshExpiresIn => _refreshExpiresIn;

  bool get isLoggedIn => _accessToken != null && _refreshToken != null;

  Future<void> loadTokens() async {
    final tokens = await SecureStorageService.getTokens();
    _accessToken = tokens['access_token'];
    _refreshToken = tokens['refresh_token'];
    _expiresIn = int.tryParse(tokens['expires_in'] ?? '');
    _refreshExpiresIn = int.tryParse(tokens['refresh_expires_in'] ?? '');
    notifyListeners();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required int refreshExpiresIn,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresIn = expiresIn;
    _refreshExpiresIn = refreshExpiresIn;
    await SecureStorageService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      refreshExpiresIn: refreshExpiresIn,
    );
    notifyListeners();
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresIn = null;
    _refreshExpiresIn = null;
    await SecureStorageService.clearTokens();
    notifyListeners();
  }
}
