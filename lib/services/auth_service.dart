import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class AuthService {
  // 로그아웃
  static Future<void> logout(BuildContext context) async {
    // 카카오 로그아웃
    try {
      await UserApi.instance.logout();
    } catch (e) {
      // 로그아웃 실패 시에도 로그인 페이지로 이동
    }

    // 로그인 페이지로 이동
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // 회원탈퇴(예시)
  static Future<void> withdraw(BuildContext context) async {
    // 카카오 연결 해제
    try {
      await UserApi.instance.unlink();
    } catch (e) {
      // 연결 해제 실패 시에도 로그아웃 처리
    }

    await logout(context);
  }
}
