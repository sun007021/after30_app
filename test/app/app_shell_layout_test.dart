import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/app/widgets/app_tab_bar.dart';
import 'package:after30/core/design/design.dart';

import 'app_shell_test_utils.dart';

/// 테스트 좌표계에서 위젯 하나의 전역 사각형을 구한다(디버깅/단언에 편하게).
Rect _globalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder.first);
  final origin = box.localToGlobal(Offset.zero);
  return origin & box.size;
}

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

  // N1(재검토): 안전 영역이 0인 테스트 기본값에서는 통과하던 위 테스트들이
  // 실제 아이폰 세이프 에어리어(상단 노치/다이나믹 아일랜드, 하단 홈
  // 인디케이터)에서는 안 통하는 회귀가 있었다 — 셸의 Scaffold가
  // extendBody:true로 body 하위에 주입하는 padding.bottom을 탭바 자신의
  // 위치 계산(SafeArea)과 다른 화면의 AlarmBottomNavigation이 다시
  // 읽어버려 이중으로 부풀려졌다. iPhone 17 Pro 상당의 실제 해상도/세이프
  // 에어리어로 재현하고 고정한다.
  group('실제 세이프 에어리어(iPhone 17 Pro 상당, 402x874, 하단 34)에서(N1)', () {
    const physicalSize = Size(1206, 2622);
    const devicePixelRatio = 3.0;
    const logicalBottomSafeArea = 34.0; // 102 physical / 3
    const logicalTopSafeArea = 62.0; // 186 physical / 3(다이나믹 아일랜드)
    const screenHeight = 2622 / devicePixelRatio; // 874

    void applyRealisticSafeArea(WidgetTester tester) {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = devicePixelRatio;
      // padding과 viewPadding을 모두 맞춰준다 — Android 탭바
      // (_AndroidTabBar)는 viewPadding.bottom을 읽는다.
      tester.view.padding = const FakeViewPadding(
        top: logicalTopSafeArea * devicePixelRatio,
        bottom: logicalBottomSafeArea * devicePixelRatio,
      );
      tester.view.viewPadding = const FakeViewPadding(
        top: logicalTopSafeArea * devicePixelRatio,
        bottom: logicalBottomSafeArea * devicePixelRatio,
      );
      addTearDown(tester.view.reset);
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

      testWidgets('$label: 탭바 위치, 마지막 항목, 서브 페이지 CTA, 키보드, SnackBar', (
        tester,
      ) async {
        applyRealisticSafeArea(tester);

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

        // 1) 탭바(iOS는 글래스 캡슐, Android는 AppTabBar 자체)가 화면
        // 하단에서 정확히 세이프 에어리어(34) + 여백(8) 위에 있다. (iOS만
        // 정확한 8pt 여백을 규정한다 — Android는 기존 디자인을 그대로
        // 재현한 것이라 별도 여백 스펙이 없다.)
        if (platform == TargetPlatform.iOS) {
          final bar = _globalRect(tester, find.byType(GlassSurface));
          expect(
            bar.bottom,
            closeTo(screenHeight - logicalBottomSafeArea - AppTabBar.bottomMargin, 0.5),
            reason: '탭바가 화면 하단에서 세이프 에어리어+여백(42pt) 위에 떠 있어야 한다',
          );
        }

        // 2) 탭 루트의 마지막 항목이 탭바에 가려지지 않고 탭할 수 있다.
        await tester.scrollUntilVisible(
          find.text('last-item-button'),
          300,
          scrollable: find.byType(Scrollable),
        );
        await tester.pump();
        final lastItem = _globalRect(tester, find.widgetWithText(ElevatedButton, 'last-item-button'));
        if (platform == TargetPlatform.iOS) {
          final barTop = _globalRect(tester, find.byType(GlassSurface)).top;
          expect(
            lastItem.bottom,
            lessThanOrEqualTo(barTop + 0.5),
            reason: '마지막 항목이 탭바 위(또는 같은 높이)에서 끝나야 한다',
          );
        }
        await tester.tap(find.text('last-item-button'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('last-item-snackbar'), findsOneWidget);

        // 3) SnackBar가 탭바 위에 있다(M1).
        final snackBar = _globalRect(tester, find.byType(SnackBar));
        if (platform == TargetPlatform.iOS) {
          final barTop = _globalRect(tester, find.byType(GlassSurface)).top;
          expect(
            snackBar.bottom,
            lessThanOrEqualTo(barTop + 0.5),
            reason: 'SnackBar가 탭바 아래로 깔리면 안 된다',
          );
        } else {
          expect(
            snackBar.bottom,
            lessThan(screenHeight - 10),
            reason: 'SnackBar가 화면 맨 아래(탭바 아래)로 깔리면 안 된다',
          );
        }

        // 4) bottomNavigationBar가 아예 없는 서브 페이지를 열어도, CTA가
        // 탭바를 가리지 않는다 — 셸이 탭 안에서 push된 화면까지 챙길
        // 필요는 없고, 화면 자신이 평범한 SafeArea만 써도 저절로
        // 맞아떨어진다(extendBody가 주입하는 padding.bottom 덕분).
        final tabNavigator = tester.state<NavigatorState>(find.byType(Navigator).at(1));
        tabNavigator.push(
          MaterialPageRoute<void>(builder: (_) => const SubPageCtaNoBottomBar()),
        );
        await tester.pumpAndSettle();

        final cta = _globalRect(tester, find.widgetWithText(ElevatedButton, 'sub-page-cta'));
        if (platform == TargetPlatform.iOS) {
          final barTop = _globalRect(tester, find.byType(GlassSurface)).top;
          expect(
            cta.bottom,
            lessThanOrEqualTo(barTop + 0.5),
            reason: 'bottomNavigationBar가 없는 서브 페이지의 CTA도 탭바를 가리면 안 된다',
          );
        }

        // 5) 키보드가 올라오면(iOS 실제 동작: 그 순간 padding.bottom은
        // 0으로 보고된다 — 홈 인디케이터 자리를 키보드가 대신 차지) CTA는
        // 키보드 바로 위에서(추가 여백 없이) 끝나고, 플로팅 탭바는 숨는다.
        const keyboardHeight = 336.0;
        tester.view.viewInsets = const FakeViewPadding(
          bottom: keyboardHeight * devicePixelRatio,
        );
        tester.view.padding = FakeViewPadding(
          top: logicalTopSafeArea * devicePixelRatio,
          bottom: 0,
        );
        tester.view.viewPadding = FakeViewPadding(
          top: logicalTopSafeArea * devicePixelRatio,
          bottom: keyboardHeight * devicePixelRatio,
        );
        await tester.pumpAndSettle();

        final ctaWithKeyboard = _globalRect(
          tester,
          find.widgetWithText(ElevatedButton, 'sub-page-cta'),
        );
        if (platform == TargetPlatform.iOS) {
          // iOS: 키보드가 올라오면 플로팅 탭바가 통째로 숨으므로(위
          // if(!keyboardOpen) 분기), CTA는 키보드 바로 위에서 추가 여백
          // 없이 끝난다.
          expect(find.byType(AppTabBar), findsNothing, reason: '키보드 위에 탭바가 뜨면 안 된다');
          expect(
            ctaWithKeyboard.bottom,
            closeTo(screenHeight - keyboardHeight, 0.5),
            reason: 'CTA가 키보드 바로 위에서(여분의 틈 없이) 끝나야 한다',
          );
        } else {
          // Android: 탭바는 키보드가 떠도 계속 보인다(기존 동작 그대로,
          // B3). 셸 Scaffold가 resizeToAvoidBottomInset으로 탭바 높이만큼
          // 더 줄어들기 때문에 CTA는 "키보드 위" 그 자체가 아니라 "키보드
          // + 탭바" 위에서 끝난다 — 정확한 탭바 높이까지 규정하진 않고,
          // 최소한 키보드 위(그 이상)에서 끝나는지만 확인한다.
          expect(find.byType(AppTabBar), findsOneWidget);
          expect(
            ctaWithKeyboard.bottom,
            lessThanOrEqualTo(screenHeight - keyboardHeight + 0.5),
            reason: 'CTA가 키보드 아래로 깔리면 안 된다',
          );
        }
      });
    }

    // N8: 키보드가 올라와 있는 동안 push된 화면은 그 순간의 예약 높이(0)를
    // 읽는데, 키보드를 내려도 다시 빌드되지 않으면 하단이 글래스 캡슐에
    // 영구히 가린다. 실제 경로는 "가족 그룹 이름 입력 → 키보드를 띄운 채
    // '다음' → 초대 화면(하단 CTA + AlarmBottomNavigation)"이다.
    testWidgets('iOS: 키보드가 떠 있는 동안 push된 화면도 키보드를 내리면 CTA가 탭바 위에 있다(N8)', (
      tester,
    ) async {
      applyRealisticSafeArea(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
          home: AppShell(
            initialIndex: AppShellTab.family,
            pageBuilders: testPageBuilders(),
          ),
        ),
      );
      await tester.pump();

      // 1) 키보드를 올린다(iOS는 이때 padding.bottom을 0으로 보고한다).
      const keyboardHeight = 336.0;
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight * devicePixelRatio,
      );
      tester.view.padding = const FakeViewPadding(
        top: logicalTopSafeArea * devicePixelRatio,
        bottom: 0,
      );
      await tester.pumpAndSettle();

      // 2) 키보드가 올라와 있는 그 프레임에 하위 화면을 push한다.
      final tabNavigator = tester.state<NavigatorState>(find.byType(Navigator).at(1));
      tabNavigator.push(
        MaterialPageRoute<void>(builder: (_) => const SubPageCtaWithBottomBar()),
      );
      await tester.pumpAndSettle();

      // 3) 키보드를 내린다 — 예약 높이가 다시 커지므로 그 화면도 새 값으로
      // 다시 빌드돼야 한다.
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(
        top: logicalTopSafeArea * devicePixelRatio,
        bottom: logicalBottomSafeArea * devicePixelRatio,
      );
      await tester.pumpAndSettle();

      final cta = _globalRect(
        tester,
        find.widgetWithText(ElevatedButton, 'bottombar-sub-page-cta'),
      );
      final barTop = _globalRect(tester, find.byType(GlassSurface)).top;
      expect(
        cta.bottom,
        lessThanOrEqualTo(barTop + 0.5),
        reason: '키보드를 내린 뒤에도 CTA가 탭바 위에서 끝나야 한다(예약 높이 재구독)',
      );
    });
  });
}
