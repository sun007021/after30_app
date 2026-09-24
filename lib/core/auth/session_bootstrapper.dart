import 'dart:async';

import 'package:flutter/material.dart';
import 'package:after30/core/auth/alarm_namespace_migrator.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/core/auth/current_user_resolver.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/services/notifications/fcm_service.dart';

/// 로그인/가입 성공 또는 세션 복원 직후에 필요한 공통 후처리를 한 곳에
/// 모은다(plan §6 W3a 1항). 예전에는 이 로직이 `login.dart`,
/// `email_login_page.dart`, `signup_intro.dart`, `main.dart`(StartupPage)에
/// 각각 조금씩 다르게(그리고 제공자마다 다른 값을 "현재 사용자 ID"로
/// 취급하며) 중복돼 있었다.
class SessionBootstrapper {
  SessionBootstrapper._();

  /// 로그인/가입 화면에서 호출한다. [providerClient]가 사용자 취소로 null을
  /// 반환하면 아무 것도 하지 않고 조용히 반환한다(기존 동작 유지). 성공하면
  /// 공통 후처리를 마치고 [context]의 루트 내비게이터로 앱 셸에 진입한다.
  static Future<void> completeLogin(
    BuildContext context,
    AuthProviderClient providerClient,
  ) async {
    final result = await providerClient.signIn();
    if (result == null) return; // 사용자가 로그인을 취소함

    final resolved = await CurrentUserResolver.resolveUserId();
    final newUserId = resolved?.toString() ?? result.fallbackUserId;

    if (newUserId != null) {
      // 리뷰 M2/M3: 마이그레이션 소스는 UserStore(로그아웃 시 비워지고,
      // 다른 계정이 남겨둔 값일 수도 있다)가 아니라 "이번에 로그인한 계정
      // 자신의" 예전 식별자 후보([AuthSignInResult.legacyUserIds])여야
      // 한다. 후보가 여러 개일 수 있어(현재는 provider당 1개) 모두
      // 시도한다 — 이미 다른 ID로 옮겨졌거나 데이터가 없는 후보는
      // [AlarmNamespaceMigrator]가 스스로 건너뛴다.
      for (final legacyId in result.legacyUserIds) {
        await AlarmNamespaceMigrator.migrateIfNeeded(
          oldUserId: legacyId,
          newUserId: newUserId,
        );
      }
      await UserStore.setCurrentUserId(newUserId);
      AlarmService.setCurrentUserId(newUserId);
    }

    // 사용자 네임스페이스가 정리된 뒤 저장된 활성 알람을 기기에 재예약한다.
    await AlarmService().rescheduleAllActiveFromStorage();
    // 로그인 성공 시 FCM 토큰을 백엔드로 동기화한다(홈 진입 전에 완료).
    await FcmService.syncTokenToBackend();

    if (!context.mounted) return;
    _enterShell(context);
  }

  /// 앱 시작 시 세션 복원(`StartupPage`)에서 호출한다. 리프레시 성공
  /// 여부를 반환하며, 실패하면 후처리를 수행하지 않는다(호출부가 온보딩/
  /// 로그인 화면으로 보낸다).
  static Future<bool> restore() async {
    final refreshed = await BackendAuthService().refreshSession();
    if (!refreshed) return false;

    // 세션 복원은 로그아웃 없이 이어지는 "같은 세션"이므로(리뷰 M2 설명과
    // 대비되는 지점), UserStore에 남은 값을 그대로 이전 ID로 써도 안전하다
    // — completeLogin처럼 다른 계정의 값을 잘못 물려받을 위험이 없다.
    final oldUserId = await UserStore.getCurrentUserId();
    final resolved = await CurrentUserResolver.resolveUserId();
    // 리뷰 M5: JWT 파싱도 실패하고 폴백도 없으면 최소한 oldUserId라도 써서
    // AlarmService 네임스페이스가 null로 남아 알람이 전혀 재예약되지 않는
    // 상황을 막는다.
    final newUserId = resolved?.toString() ?? oldUserId;

    if (newUserId != null) {
      if (oldUserId != null) {
        await AlarmNamespaceMigrator.migrateIfNeeded(
          oldUserId: oldUserId,
          newUserId: newUserId,
        );
      }
      await UserStore.setCurrentUserId(newUserId);
      AlarmService.setCurrentUserId(newUserId);
    }

    await AlarmService().rescheduleAllActiveFromStorage();
    // 리뷰 M6: 스플래시 화면이 네트워크 응답을 기다리지 않게 한다(로그인
    // 흐름과 달리 세션 복원은 사용자를 최대한 빨리 홈으로 보내야 한다).
    unawaited(FcmService.syncTokenToBackend());
    return true;
  }

  static void _enterShell(BuildContext context) {
    // 셸 밖에서 셸로 들어가는 이동이므로 루트 내비게이터를 쓴다(plan §3
    // 원칙, R3 공통 규칙 — AuthService.logout과 대칭되는 진입 경로).
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
