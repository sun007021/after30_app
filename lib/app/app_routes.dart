import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/gallery/design_gallery_page.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/login/ui/login.dart';
import 'package:after30/features/login/ui/signup_intro.dart';
import 'package:after30/features/login/ui/signup_page.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';
import 'package:after30/features/my/my_info_edit_page.dart';
import 'package:after30/features/my/my_info_page.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:after30/features/onboarding/ui/onboarding_page.dart';

/// 앱 전역 라우트 이름 테이블(PR #31 B1) — `/startup`, `/fullscreen_alarm`
/// 제외. 이 두 라우트는 `main.dart`가 소유한(W3/W4가 계속 작업 중인)
/// `StartupPage`/`FullscreenAlarmPlaceholder`를 그대로 써야 해서(N3),
/// `main.dart`가 [buildAppRoutes]에 자신의 빌더를 넘겨 완성한다. 탭
/// Navigator의 `onGenerateRoute`([generateTabRoute])는 이 두 라우트를
/// 다루지 않으므로(둘 다 셸을 벗어나는 라우트라 [kTabLocalRouteNames]에
/// 없음) 이 부분 집합만으로 충분하다.
final Map<String, WidgetBuilder> appRoutes = {
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
  '/my': (context) => const MyPage(),
  '/my-info': (context) => const MyInfoPage(),
  '/my-info-edit': (context) => const MyInfoEditPage(),
  if (kDebugMode) '/dev/design-gallery': (context) => const DesignGalleryPage(),
};

/// `MaterialApp.routes`용 완성된 라우트 테이블을 만든다(N3). `/startup`,
/// `/fullscreen_alarm`은 `main.dart`가 소유한 위젯이라 여기서 직접
/// import하지 않고 호출부가 빌더를 넘겨준다 — `app_routes.dart`가
/// `main.dart`를 import하면(반대로 `main.dart`는 이미 이 파일을
/// import한다) 순환 참조가 생기고, `StartupPage`/`FullscreenAlarmPlaceholder`가
/// 어느 워크스트림 소유인지도 애매해진다.
Map<String, WidgetBuilder> buildAppRoutes({
  required WidgetBuilder startup,
  required WidgetBuilder fullscreenAlarm,
}) {
  return {'/startup': startup, ...appRoutes, '/fullscreen_alarm': fullscreenAlarm};
}

/// 탭 Navigator 안에서 그대로 push해도 되는(탭 스택에 남아도 되는) 라우트
/// 이름들. 여기 없는 이름(특히 로그인/온보딩/홈처럼 셸을 벗어나야 하는
/// 라우트)은 [generateTabRoute]가 루트 내비게이터로 전달한다.
const Set<String> kTabLocalRouteNames = {'/my-info', '/my-info-edit'};

/// 탭 안에서 push되면 안 되는(셸을 완전히 벗어나야 하는) 라우트 이름들
/// (N4). [kTabLocalRouteNames]에도 이 집합에도 없는 이름은 "알 수 없는
/// 이름"으로 취급해 아무 데도 보내지 않는다 — 함부로 루트로 보내버리면
/// 오타/등록 누락을 조용히 셸 탈출로 둔갑시키게 된다.
const Set<String> kShellExitRouteNames = {
  '/startup',
  '/onboarding',
  '/login',
  '/signup-intro',
  '/signup-terms',
  '/email-login',
  '/signup',
  '/home',
  '/fullscreen_alarm',
};

/// [AppShell] 탭 Navigator용 `onGenerateRoute`(PR #31 B1).
///
/// - [kTabLocalRouteNames]에 있는 이름은 [appRoutes]에서 빌더를 찾아
///   `MaterialPageRoute`로 탭 스택에 그대로 쌓는다(예: 마이 탭 안에서의
///   `/my-info`, `/my-info-edit`). `MaterialPageRoute`를 써야 플랫폼
///   기본 전환(iOS 푸시 애니메이션 + 엣지 스와이프 백)을 그대로 받는다
///   (N2) — 전환 시간 0인 `PageRouteBuilder`를 쓰면 이게 사라진다.
///   Android는 앱 테마의 `pageTransitionsTheme`가 이미 전환 없음으로
///   설정돼 있어 동작이 그대로 유지된다.
/// - 그 외 이름은 [_ShellExitForwarder]가 처리한다(N4).
Route<dynamic> generateTabRoute(RouteSettings settings) {
  final name = settings.name;
  final builder = (name != null && kTabLocalRouteNames.contains(name))
      ? appRoutes[name]
      : null;

  if (builder != null) {
    return MaterialPageRoute<void>(settings: settings, builder: builder);
  }

  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, _, __) => _ShellExitForwarder(routeSettings: settings),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// 탭 스택에 쌓이면 안 되는 라우트를 처리하는 투명한 중계 위젯(N4).
///
/// - 이름이 [kShellExitRouteNames]에 있으면(예: `/login`, `/home`) 원래
///   이 라우트는 `Navigator.of(context, rootNavigator: true)`로 push됐어야
///   한다 — 디버그 빌드에서는 그 실수를 [FlutterError]로 크게 알리고,
///   릴리스 빌드에서는 조용히 복구하기 위해 루트 내비게이터로
///   `pushNamedAndRemoveUntil`을 대신 호출해(셸 전체를 걷어내고 새로
///   시작) 최소한 사용자가 셸 안에 갇히지는 않게 한다.
/// - 이름이 알 수 없는(둘 중 어디에도 없는) 경우 — 오타이거나 탭 로컬
///   라우트 등록을 빠뜨린 경우다. 디버그에서는 역시 크게 알리고,
///   릴리스에서는 아무 데도 보내지 않고 그냥 이 화면을 pop한다(어디로
///   보내야 할지 모르는 상태에서 함부로 셸을 걷어내는 것보다 안전하다).
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
    final name = widget.routeSettings.name;
    final isShellExit = name != null && kShellExitRouteNames.contains(name);

    assert(() {
      if (isShellExit) {
        throw FlutterError.fromParts([
          ErrorSummary(
            "탭 Navigator 안에서 셸을 벗어나야 하는 라우트 '$name'을(를) "
            'rootNavigator 없이 push했습니다.',
          ),
          ErrorDescription(
            'Navigator.of(context).pushNamed(...) 대신 '
            "Navigator.of(context, rootNavigator: true).pushNamed('$name', ...)를 "
            '쓰세요. 릴리스 빌드에서는 이 실수를 조용히 복구하려고 루트 '
            '내비게이터로 대신 전달하지만(pushNamedAndRemoveUntil, 셸 전체를 '
            '걷어냄), 디버그에서는 호출부를 고치라는 신호로 예외를 던집니다.',
          ),
        ]);
      }
      throw FlutterError.fromParts([
        ErrorSummary("탭 Navigator가 모르는 라우트 이름 '$name'을(를) push했습니다."),
        ErrorDescription(
          'appRoutes에도 없고 셸을 벗어나야 하는 라우트 목록에도 없습니다. '
          '오타이거나 탭 로컬 라우트 등록을 빠뜨렸을 수 있습니다. 릴리스 '
          '빌드에서는 아무 데도 보내지 않고 이 화면을 그냥 pop합니다.',
        ),
      ]);
    }());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isShellExit) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(name, (route) => false);
      }
      // 알 수 없는 이름이면 어디로도 보내지 않고 이 자리(탭 스택)만
      // 정리한다.
      final tabNavigator = Navigator.of(context);
      if (tabNavigator.canPop()) {
        tabNavigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// FamilyPage는 W10 이전에 '/family'라는 최상위 이름 라우트로도 등록돼
// 있었지만, 어디에서도 이름으로 push하지 않고(grep 결과 없음) AppShell의
// 가족 탭(pushNamed가 아니라 `AppShell.of(context).switchTab`)으로만
// 진입한다. 게다가 `FamilyPage`는 내부에서 `AppShell.of(context)`를 호출하는
// 코드(전화번호 등록 팝업의 "취소"/"마이페이지로" 동작)가 있어, 셸 밖에서
// 이 라우트로 직접 진입하면 크래시한다. 죽은 코드를 안전한 것처럼 남겨두는
// 대신 라우트 자체를 제거했다(m3).
