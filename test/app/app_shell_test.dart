import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    // handleBackButton()의 3단계(홈 루트)에서 SystemNavigator.pop()을
    // 호출하는데, 위젯 테스트 환경에는 이를 처리할 플랫폼이 없어 응답 없이
    // 무한 대기할 수 있다. 'flutter/platform' 채널을 미리 목(mock)으로
    // 등록해 즉시 응답하게 한다(실제 종료 여부는 검증 대상이 아니며,
    // 예외 없이 호출이 끝나는지만 확인한다).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

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

  testWidgets('popOriginToRoot: true면 출발 탭의 스택도 함께 루트로 정리된다(M3)', (tester) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);

    // 홈 탭에서 서브 페이지를 연다(예: 홈에서 가족 그룹 초대 플로우를
    // 여는 것에 대응).
    await tester.tap(find.text('push sub'));
    await tester.pumpAndSettle();
    expect(find.text('home-sub-page'), findsOneWidget);

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.family, popOriginToRoot: true);
    await tester.pumpAndSettle();
    expect(shellState.currentIndex, AppShellTab.family);

    // 홈 탭으로 되돌아가면(재탭이 아니라 그냥 전환) 서브 페이지가 남아있지
    // 않아야 한다 — popOriginToRoot가 출발 탭도 정리했다는 뜻이다.
    shellState.switchTab(AppShellTab.home);
    await tester.pumpAndSettle();
    expect(find.text('home-sub-page'), findsNothing);
    expect(find.textContaining('home:'), findsOneWidget);
  });

  testWidgets('resetArguments: true면 arguments가 null이어도 루트 화면을 다시 만든다(M6)', (
    tester,
  ) async {
    await pumpAppShell(tester, initialIndex: AppShellTab.home);
    final shellState = tester.state<AppShellState>(find.byType(AppShell));

    shellState.switchTab(AppShellTab.family, arguments: 7);
    await tester.pump();
    expect(find.text('family-7:0'), findsOneWidget);
    shellState.switchTab(AppShellTab.home);
    await tester.pump();

    // arguments 없이(null) popToRoot만 하면 이전에 열어둔 그룹(7)이 그대로
    // 남아있다 — 애초에 루트를 다시 만들 필요가 없다고 해석되기 때문.
    shellState.switchTab(AppShellTab.family, popToRoot: true);
    await tester.pump();
    expect(find.text('family-7:0'), findsOneWidget);
    shellState.switchTab(AppShellTab.home);
    await tester.pump();

    // resetArguments: true를 주면 인자가 null이어도 루트를 강제로 다시
    // 만들어, 이전 그룹이 남아있지 않고 "그룹 미지정" 초기 상태가 된다.
    shellState.switchTab(AppShellTab.family, popToRoot: true, resetArguments: true);
    await tester.pump();
    expect(find.text('family-7:0'), findsNothing);
    expect(find.text('family:0'), findsOneWidget);
  });

  testWidgets('탭이 재활성화되면(전환 또는 재탭) AppShellTabAware 훅이 호출된다(M2)', (
    tester,
  ) async {
    var activations = 0;
    final builders = testPageBuilders();
    builders[AppShellTab.home] = (context, args) => AppShellTabActivationListener(
      tabIndex: AppShellTab.home,
      onActivated: () => activations++,
      child: const CounterStubPage(tag: 'home-aware'),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.build(), home: AppShell(pageBuilders: builders)),
    );
    await tester.pump();
    expect(activations, 0); // 최초 진입은 "재"활성화가 아니므로 훅 대상이 아니다.

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.alarm);
    await tester.pump();
    expect(activations, 0); // 아직 홈 탭으로 돌아오지 않았다.

    shellState.switchTab(AppShellTab.home);
    await tester.pump();
    expect(activations, 1);

    // 재탭(같은 탭 재선택)도 활성화로 취급된다.
    shellState.switchTab(AppShellTab.home);
    await tester.pump();
    expect(activations, 2);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

    testWidgets('$label: 탭바를 직접 탭하면 전환되고, 다시 탭하면(재탭) 루트로 pop한다(m7)', (
      tester,
    ) async {
      await pumpAppShell(tester, platform: platform, initialIndex: AppShellTab.home);

      Finder familyTabFinder() {
        if (platform == TargetPlatform.iOS) return find.text('가족');
        return find.byWidgetPredicate((widget) {
          if (widget is! SvgPicture) return false;
          final loader = widget.bytesLoader;
          return loader is SvgAssetLoader &&
              loader.assetName.contains('navicon/fam_');
        });
      }

      await tester.tap(familyTabFinder());
      await tester.pump();
      expect(find.textContaining('family:'), findsOneWidget);

      await tester.tap(find.text('push sub'));
      await tester.pumpAndSettle();
      expect(find.text('family-sub-page'), findsOneWidget);

      // 같은 탭을 다시 탭하면(재탭) 서브 페이지가 닫히고 루트로 돌아간다.
      await tester.tap(familyTabFinder());
      await tester.pumpAndSettle();
      expect(find.text('family-sub-page'), findsNothing);
      expect(find.textContaining('family:'), findsOneWidget);
    });
  }
}
