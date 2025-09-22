import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/services/token_store.dart';

class AuthService {
  /// 카카오 로그아웃 + 앱 세션 정리
  static Future<void> logout(BuildContext context) async {
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await TokenStore.clear();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /// 카카오 연결 해제 후 로그아웃
  static Future<void> withdraw(BuildContext context) async {
    try {
      await UserApi.instance.unlink();
    } catch (_) {}
    await logout(context);
  }

  // 저장/조회는 TokenStore를 직접 사용하세요.
}
