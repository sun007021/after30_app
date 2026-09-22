import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/gallery/design_gallery_page.dart';
import 'package:after30/core/storage/onboarding_store.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/login/ui/login.dart';
import 'package:after30/features/login/ui/signup_intro.dart';
import 'package:after30/features/login/ui/signup_page.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';
import 'package:after30/features/my/my_info_edit_page.dart';
import 'package:after30/features/my/my_info_page.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:after30/features/onboarding/ui/onboarding_page.dart';

/// 앱 전역 라우트 이름 테이블(PR #31 B1). 기존에는 `main.dart`의
/// `MaterialApp.routes`에만 있었는데, [AppShell] 탭 안에서 이름 있는
/// 라우트를 push하면(`pushNamed`) 탭 Navigator가 이 테이블을 몰라
/// "onGenerateRoute was null"로 죽었다. `MaterialApp.routes`와 각 탭
/// Navigator의 `onGenerateRoute`([generateTabRoute])가 이 맵 하나를
/// 공유하도록 분리했다.
final Map<String, WidgetBuilder> appRoutes = {
  '/startup': (context) => const StartupPage(),
  '/onboarding': (context) => const OnboardingPage(),
  '/login': (context) => const LoginPage(),
  '/signup-intro': (context) => const SignupIntroPage(),
  '/signup-terms': (context) => const TermsAgreementPage(),
  '/email-login': (context) => const EmailLoginPage(),
  '/signup': (context) => const SignupPage(),
  // 알림/로그인 이후 '/home'으로 이동하는 기존 경로들은 앱 셸(AppShell)의
  // 홈 탭으로 진입한다(plan §6 W10 4항). AppShell의 기본 탭이 홈이므로
  // 별도 인자 없이 그대로 쓴다.
  '/home': (context) => const AppShell(),
  '/fullscreen_alarm': (context) => const FullscreenAlarmPlaceholder(),
  '/my': (context) => const MyPage(),
  '/my-info': (context) => const MyInfoPage(),
  '/my-info-edit': (context) => const MyInfoEditPage(),
  if (kDebugMode) '/dev/design-gallery': (context) => const DesignGalleryPage(),
};

/// 탭 Navigator 안에서 그대로 push해도 되는(탭 스택에 남아도 되는) 라우트
/// 이름들. 여기 없는 이름(특히 로그인/온보딩/홈처럼 셸을 벗어나야 하는
/// 라우트)은 [generateTabRoute]가 루트 내비게이터로 전달한다.
const Set<String> kTabLocalRouteNames = {'/my-info', '/my-info-edit'};

/// [AppShell] 탭 Navigator용 `onGenerateRoute`(PR #31 B1).
///
/// - [kTabLocalRouteNames]에 있는 이름은 [appRoutes]에서 빌더를 찾아 탭
///   스택에 그대로 쌓는다(예: 마이 탭 안에서의 `/my-info`, `/my-info-edit`).
/// - 그 외 이름(예: `/login`, `/home`)은 탭 안에 남아서는 안 되는 화면이므로,
///   루트 내비게이터(`Navigator.of(context, rootNavigator: true)`)로 그대로
///   전달하고, 탭 스택에는 아무 흔적도 남기지 않는다. 로그아웃/탈퇴처럼
///   이미 `rootNavigator: true`를 쓰는 호출부가 정상 동작이고, 이 분기는
///   실수로 rootNavigator 없이 셸 안에서 이런 라우트를 부르더라도 최소한
///   크래시 없이 셸을 벗어나게 하는 안전장치다.
Route<dynamic> generateTabRoute(RouteSettings settings) {
  final name = settings.name;
  final builder = (name != null && kTabLocalRouteNames.contains(name))
      ? appRoutes[name]
      : null;

  if (builder != null) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (context, _, __) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, _, __) => _ShellExitForwarder(routeSettings: settings),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// 탭 스택에 쌓이면 안 되는 라우트를 루트 내비게이터로 넘기고, 자기 자신은
/// 탭 스택에서 바로 pop하는 투명한 중계 위젯.
class _ShellExitForwarder extends StatefulWidget {
  const _ShellExitForwarder({required this.routeSettings});

  final RouteSettings routeSettings;

  @override
  State<_ShellExitForwarder> createState() => _ShellExitForwarderState();
}

class _ShellExitForwarderState extends State<_ShellExitForwarder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = widget.routeSettings.name;
      if (name != null) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamed(name, arguments: widget.routeSettings.arguments);
      }
      final tabNavigator = Navigator.of(context);
      if (tabNavigator.canPop()) {
        tabNavigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// 전체화면 알림을 위한 플레이스홀더
class FullscreenAlarmPlaceholder extends StatelessWidget {
  const FullscreenAlarmPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제로는 알람 데이터를 받아와서 FullscreenAlarm을 표시해야 합니다
    return const Scaffold(body: Center(child: Text('전체화면 알림')));
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _attemptRefresh();
  }

  Future<void> _attemptRefresh() async {
    try {
      // FullScreen Intent로 앱이 기동된 경우에만 풀스크린 라우트로 이동
      try {
        final initialAction = await AwesomeNotifications()
            .getInitialNotificationAction();
        if (initialAction != null) {
          final payload = initialAction.payload ?? {};
          final isFs = payload['fs'] == '1';
          // 앱이 알림으로 콜드 스타트된 경우, 잠금이 풀려 있어도 풀스크린
          // 알람 화면을 보여준다(잠금 여부와 무관하게 사용자가 알림으로
          // 앱을 열었다는 사실 자체가 이동 의도를 나타낸다).
          if (isFs) {
            final alarmId = payload['alarmId'] ?? '';
            final name = payload['medicineName'] ?? '약';
            final timeStr = payload['time'] ?? '08:00';
            final day = payload['day'] ?? '월';
            final notifId = initialAction.id ?? 0;
            final hour = int.tryParse(timeStr.split(':').first) ?? 8;
            final minute = int.tryParse(timeStr.split(':').last) ?? 0;
            if (!mounted) return;
            AlarmService.showFullscreenAlarm(
              context,
              MedicineAlarm(
                id: alarmId.isEmpty ? null : alarmId,
                name: name,
                times: [TimeOfDay(hour: hour, minute: minute)],
                days: [day],
              ),
              TimeOfDay(hour: hour, minute: minute),
              day,
              notificationId: notifId,
            );
            return;
          }
        }
      } catch (_) {}

      final ok = await BackendAuthService().refreshSession();
      if (!mounted) return;
      if (ok) {
        await OnboardingStore.setCompleted();
        // 저장된 사용자 ID가 있다면 네임스페이스 설정 후 재스케줄
        final userId = await UserStore.getCurrentUserId();
        AlarmService.setCurrentUserId(userId);
        await AlarmService().rescheduleAllActiveFromStorage();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        await _goToOnboardingOrLogin();
      }
    } catch (_) {
      if (!mounted) return;
      await _goToOnboardingOrLogin();
    }
  }

  Future<void> _goToOnboardingOrLogin() async {
    final seenOnboarding = await OnboardingStore.isCompleted();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(seenOnboarding ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SvgPicture.asset(
          'assets/images/mainicon.svg',
          width: 80,
          height: 80,
        ),
      ),
    );
  }
}

// FamilyPage는 W10 이전에 '/family'라는 최상위 이름 라우트로도 등록돼
// 있었지만, 어디에서도 이름으로 push하지 않고(grep 결과 없음) AppShell의
// 가족 탭(pushNamed가 아니라 `AppShell.of(context).switchTab`)으로만
// 진입한다. 게다가 `FamilyPage`는 내부에서 `AppShell.of(context)`를 호출하는
// 코드(전화번호 등록 팝업의 "취소"/"마이페이지로" 동작)가 있어, 셸 밖에서
// 이 라우트로 직접 진입하면 크래시한다. 죽은 코드를 안전한 것처럼 남겨두는
// 대신 라우트 자체를 제거했다(m3).
