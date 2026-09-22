import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/core/storage/user_store.dart';

class AuthService {
  /// 카카오 로그아웃 + 앱 세션 정리
  static Future<void> logout(BuildContext context) async {
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    // 기기에 예약된 알림만 취소하고, 저장된 알람 데이터는 유지(재로그인 시 복구용)
    await AlarmService().cancelAllActiveAlarmSchedules();
    await TokenStore.clear();
    await UserStore.clear();
    AlarmService.setCurrentUserId(null);
    if (context.mounted) {
      // 이 메서드는 앱 셸(AppShell) 탭 안(마이페이지 로그아웃/탈퇴 등)에서도
      // 호출된다. rootNavigator: true 없이 호출하면 가장 가까운 탭
      // Navigator를 찾아 '/login'을 push하려다가 죽는다(B1) — 이미 토큰/
      // UserStore/알람이 정리된 뒤라 사용자가 셸 안에 갇혀버리는 최악의
      // 상황이 된다. 반드시 루트 내비게이터로 이동해 셸 전체를 걷어낸다.
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
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
