import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/app/widgets/app_tab_bar.dart';
import 'package:after30/core/design/app_theme.dart';

import 'app_shell_test_utils.dart';

/// PR #31 B3 + M1: 셸의 탭바(iOS는 콘텐츠 위로 뜨는 플로팅 캡슐, Android는
/// Scaffold.bottomNavigationBar 슬롯)가 화면 하단 콘텐츠를 가리거나
/// SnackBar를 가리지 않는지 검증한다.
void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

    testWidgets('$label: 리스트 마지막 항목이 탭바에 가려지지 않고 탭할 수 있다(B3)', (
      tester,
    ) async {
      final builders = testPageBuilders();
      builders[AppShellTab.alarm] = (context, args) =>
          const ScaffoldWithListPage(currentIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build().copyWith(platform: platform),
          home: AppShell(initialIndex: AppShellTab.alarm, pageBuilders: builders),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('last-item-button'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      // 실제로 눌리는지까지 확인한다 — 단순히 화면에 존재하는 것만으로는
      // 탭바 아래 깔려 히트테스트가 안 되는 회귀를 못 잡는다.
      await tester.tap(find.text('last-item-button'));
      await tester.pump();
      // SnackBar 등장 애니메이션(약 250ms)이 끝난 뒤 위치를 재야 한다 —
      // 애니메이션 도중에는 화면 밖에서 올라오는 중이라 위치가 아직
      // 확정되지 않았다.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('last-item-snackbar'), findsOneWidget);

      // SnackBar가 화면 맨 아래까지 깔리지 않고, 탭바만큼 위로 올라와
      // 있어야 한다(M1). Flutter의 ScaffoldMessenger는 중첩된 Scaffold 중
      // "가장 바깥쪽" 하나에서만 SnackBar를 보여주는데, 그게 바로 셸
      // 자신의 Scaffold이지 이 화면의 Scaffold가 아니다 — 그래서 화면이
      // bottomNavigationBar를 뭘로 설정했는지는 SnackBar 위치와 무관하고,
      // 셸 Scaffold 자체가 자리를 예약해야만 한다.
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final snackBarBox = tester.renderObject<RenderBox>(find.byType(SnackBar).first);
      final snackBarBottomY =
          snackBarBox.localToGlobal(Offset.zero).dy + snackBarBox.size.height;
      expect(
        snackBarBottomY,
        lessThan(screenHeight - 40),
        reason: 'SnackBar가 탭바 아래(화면 맨 아래)로 깔리면 안 된다',
      );
    });
  }

  testWidgets('iOS: 키보드가 올라오면 플로팅 탭바가 숨는다(키보드 위에 뜨지 않는다)', (
    tester,
  ) async {
    await pumpAppShell(tester, platform: TargetPlatform.iOS, initialIndex: AppShellTab.home);
    expect(find.byType(AppTabBar), findsOneWidget);

    // MediaQueryData.viewInsets로 키보드가 올라온 상태를 흉내 낸다.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
          child: AppShell(pageBuilders: testPageBuilders()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppTabBar), findsNothing);
  });
}
