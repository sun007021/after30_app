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
}
