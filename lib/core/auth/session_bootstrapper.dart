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
///
/// 순서가 중요하다: 사용자 ID를 새 값으로 덮어쓰기 *전에* 이전 ID를 먼저
/// 읽어야 [AlarmNamespaceMigrator]가 옮길 대상을 알 수 있다.
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

    await _afterAuthSuccess(fallbackUserId: result.fallbackUserId);

    if (!context.mounted) return;
    _enterShell(context);
  }

  /// 앱 시작 시 세션 복원(`StartupPage`)에서 호출한다. 리프레시 성공
  /// 여부를 반환하며, 실패하면 후처리를 수행하지 않는다(호출부가 온보딩/
  /// 로그인 화면으로 보낸다).
  static Future<bool> restore() async {
    final refreshed = await BackendAuthService().refreshSession();
    if (!refreshed) return false;
    await _afterAuthSuccess();
    return true;
  }

  static Future<void> _afterAuthSuccess({String? fallbackUserId}) async {
    // 마이그레이션 대상을 정하려면 "새 ID로 덮어쓰기 전" 이전 ID가 필요하다.
    final oldUserId = await UserStore.getCurrentUserId();

    final resolved = await CurrentUserResolver.resolveUserId();
    final newUserId = resolved?.toString() ?? fallbackUserId;

    if (newUserId != null) {
      await AlarmNamespaceMigrator.migrateIfNeeded(
        oldUserId: oldUserId,
        newUserId: newUserId,
      );
      await UserStore.setCurrentUserId(newUserId);
      AlarmService.setCurrentUserId(newUserId);
    }

    // 사용자 네임스페이스가 정리된 뒤 저장된 활성 알람을 기기에 재예약한다.
    await AlarmService().rescheduleAllActiveFromStorage();
    // 로그인/세션 복원 성공 시 FCM 토큰을 백엔드로 동기화한다.
    await FcmService.syncTokenToBackend();
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
