import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'token_provider.dart';
import 'user_provider.dart';
import 'secure_storage_service.dart';
import 'package:after30/services/auth_api_service.dart';

class AuthService {
  // 로그아웃
  static Future<void> logout(BuildContext context) async {
    try {
      await AuthApiService.logout();
    } catch (_) {}
    await Provider.of<TokenProvider>(context, listen: false).clearTokens();
    await Provider.of<UserProvider>(context, listen: false).clearUser();
    await SecureStorageService.clearAll();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // 회원탈퇴(예시)
  static Future<void> withdraw(BuildContext context) async {
    // TODO: 회원탈퇴 API 호출 등
    await logout(context);
  }
}
