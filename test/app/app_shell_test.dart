import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/common/navigationBar.dart';

import 'app_shell_test_utils.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('탭을 전환해도 이전 탭의 상태(카운터)가 유지된다', (tester) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);

    // 홈 탭에서 카운터를 2로 올린다.
    await tester.tap(find.text('+1'));
    await tester.pump();
    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(find.text('home:2'), findsOneWidget);

    // 알람 탭으로 전환.
    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.alarm);
    await tester.pump();
    expect(find.text('alarm:0'), findsOneWidget);
    expect(find.text('home:2'), findsNothing);

    // 다시 홈 탭으로 돌아오면 카운터가 그대로 2다(IndexedStack이 상태를
    // 유지하고 있음을 의미).
    shellState.switchTab(AppShellTab.home);
    await tester.pump();
    expect(find.text('home:2'), findsOneWidget);
  });

  testWidgets('이미 활성화된 탭을 다시 지정하면 루트까지 pop한다', (tester) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);

    await tester.tap(find.text('push sub'));
    await tester.pumpAndSettle();
    expect(find.text('home-sub-page'), findsOneWidget);

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.home);
    await tester.pumpAndSettle();

    expect(find.text('home-sub-page'), findsNothing);
    expect(find.textContaining('home:'), findsOneWidget);
  });

  testWidgets('switchTab(arguments: ...)는 대상 탭의 루트 화면을 새 인자로 다시 만든다', (tester) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.family, arguments: 42);
    await tester.pump();

    expect(find.text('family-42:0'), findsOneWidget);
    expect(shellState.currentIndex, AppShellTab.family);
  });

  testWidgets('Android 뒤로 가기: 탭 안에서 pop → 홈 탭 → (홈 루트에서) 종료 시도', (tester) async {
    await pumpAppShell(
      tester,
      platform: TargetPlatform.android,
      initialIndex: AppShellTab.alarm,
    );
    final shellState = tester.state<AppShellState>(find.byType(AppShell));

    // 1) 탭 안에서 서브 페이지를 연 상태라면 그 서브 페이지만 pop한다.
    await tester.tap(find.text('push sub'));
    await tester.pumpAndSettle();
    expect(find.text('alarm-sub-page'), findsOneWidget);

    await shellState.handleBackButton();
    await tester.pumpAndSettle();
    expect(find.text('alarm-sub-page'), findsNothing);
    expect(shellState.currentIndex, AppShellTab.alarm);

    // 2) 탭 루트에서는 홈 탭으로 이동한다.
    await shellState.handleBackButton();
    await tester.pump();
    expect(shellState.currentIndex, AppShellTab.home);

    // 3) 홈 탭 루트에서는 종료를 시도한다(테스트 환경에는 플랫폼 채널이
    // 없으므로 예외 없이 조용히 무시되는지만 확인한다).
    await shellState.handleBackButton();
    await tester.pump();
    expect(shellState.currentIndex, AppShellTab.home);
    expect(tester.takeException(), isNull);
  });

  testWidgets("'/home' 라우트는 셸의 홈 탭으로 진입한다", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        initialRoute: '/home',
        routes: {
          '/home': (context) =>
              AppShell(pageBuilders: testPageBuilders()),
        },
      ),
    );
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    expect(shellState.currentIndex, AppShellTab.home);
    expect(find.textContaining('home:'), findsOneWidget);
  });

  testWidgets('셸 안에서는 AlarmBottomNavigation이 아무것도 그리지 않는다', (tester) async {
    final builders = testPageBuilders();
    builders[AppShellTab.alarm] = (context, args) => Scaffold(
      body: const Center(child: Text('alarm-with-legacy-navbar')),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: AppShell(initialIndex: AppShellTab.alarm, pageBuilders: builders),
      ),
    );
    await tester.pump();

    expect(find.byType(AlarmBottomNavigation), findsOneWidget);
    // AlarmBottomNavigation은 셸 안에서 빈 SizedBox만 반환하므로, 내부에
    // 기존 아이콘/제스처가 전혀 렌더링되지 않는다.
    expect(
      find.descendant(
        of: find.byType(AlarmBottomNavigation),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });
}
