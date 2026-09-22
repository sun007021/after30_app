import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_routes.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/login/ui/login.dart';
import 'package:after30/features/my/my_info_page.dart';

import 'app_shell_test_utils.dart';

/// PR #31 B1: 탭 Navigator에 onGenerateInitialRoutes만 있고
/// onGenerateRoute가 없어서, 탭 안에서 이름 있는 라우트를 pushNamed하면
/// "onGenerateRoute was null"로 죽던 문제의 회귀 테스트. 가장 심각했던
/// 경로는 로그아웃/탈퇴(auth_service.dart)로, 토큰/UserStore/알람을 모두
/// 정리한 뒤에 크래시해 사용자가 셸 안에 갇혔다.
void main() {
  testWidgets("탭 안에서 pushNamed('/my-info')를 호출해도 크래시하지 않고 탭 스택에 쌓인다(B1)", (
    tester,
  ) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.my);

    final myTabContext = tester.element(find.text('my:0'));
    Navigator.of(myTabContext).pushNamed('/my-info');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(MyInfoPage), findsOneWidget);
    // 셸/탭바는 여전히 떠 있다 — 루트가 아니라 탭 안에 쌓였다는 뜻이다.
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets(
    "탭 안에서 rootNavigator: true로 pushNamedAndRemoveUntil('/login', ...)하면 "
    '셸 전체가 걷히고 루트 /login으로 이동한다(B1, 로그아웃/탈퇴 시나리오)',
    (tester) async {
      // AuthService.logout()이 실제로 하는 것과 같은 모양: 손으로 만든
      // 라우트 맵이 아니라 공유 appRoutes를 그대로 쓴다(m7).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          initialRoute: '/home',
          routes: {
            ...appRoutes,
            '/home': (context) => AppShell(pageBuilders: testPageBuilders()),
          },
        ),
      );
      await tester.pump();

      // 기본 시작 탭은 홈이다(다른 탭은 방문 전이라 아직 만들어지지도
      // 않았다 — B2).
      final tabContext = tester.element(find.textContaining('home:'));
      Navigator.of(
        tabContext,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets("'/home' 라우트는 공유 appRoutes를 통해서도 셸의 홈 탭으로 진입한다(m7)", (
    tester,
  ) async {
    // 손으로 만든 라우트 맵이 아니라 main.dart가 실제로 쓰는 공유
    // appRoutes를 그대로 스프레드하되, '/home'만 실제 기능 화면 대신 가벼운
    // 테스트 스텁으로 덮어써서(네트워크/Firebase/카카오 호출 없이) 결정론적으로
    // 검증한다.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        initialRoute: '/home',
        routes: {
          ...appRoutes,
          '/home': (context) => AppShell(pageBuilders: testPageBuilders()),
        },
      ),
    );
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    expect(shellState.currentIndex, AppShellTab.home);
  });

  test(
    '탭 로컬 라우트(/my-info)는 MaterialPageRoute라 iOS 푸시 전환/엣지 스와이프 백을 '
    '그대로 받는다(N2)',
    () {
      // 이전에는 전환 시간이 0인 PageRouteBuilder를 썼는데, 그러면 플랫폼
      // 기본 전환(iOS 푸시 애니메이션 + 엣지 스와이프 백)이 통째로
      // 사라졌다. MaterialPageRoute는 앱 테마의 pageTransitionsTheme를
      // 그대로 따르므로(iOS는 CupertinoPageTransitionsBuilder, Android는
      // 기존 NoTransitions), 두 플랫폼 모두 원래 동작을 유지한다.
      final route = generateTabRoute(const RouteSettings(name: '/my-info'));
      expect(route, isA<MaterialPageRoute<void>>());
    },
  );

  testWidgets(
    "탭 안에서 rootNavigator 없이 셸을 벗어나는 라우트를 push하면 디버그에서 크게 실패한다(N4)",
    (tester) async {
      await pumpAppShell(tester, initialIndex: AppShellTab.home);
      final tabContext = tester.element(find.textContaining('home:'));
      // rootNavigator: true를 빠뜨린 실수 상황을 흉내 낸다.
      Navigator.of(tabContext).pushNamed('/login');
      await tester.pump();

      expect(tester.takeException(), isA<FlutterError>());
    },
  );

  testWidgets('탭 안에서 알 수 없는 라우트 이름을 push하면 디버그에서 크게 실패한다(N4)', (
    tester,
  ) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);
    final tabContext = tester.element(find.textContaining('home:'));
    Navigator.of(tabContext).pushNamed('/definitely-not-a-registered-route');
    await tester.pump();

    expect(tester.takeException(), isA<FlutterError>());
  });
}
