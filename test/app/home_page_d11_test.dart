import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';

import 'app_shell_test_utils.dart';

/// D11(2026-09-22): 로그인 직후 전화번호 등록 팝업을 더 이상 띄우지 않는다.
///
/// 원래는 `HomePage`를 단독으로 펌프해서 전화번호 팝업이 안 뜨는지만 확인
/// 했는데, 이 테스트는 너무 약했다: 실제 버그는 HomePage 자체가 아니라
/// [AppShell]이 [IndexedStack]으로 5개 탭을 한꺼번에 만들면서, 아직 보지도
/// 않은 가족 탭의 `FamilyPage.initState`가 곧바로 실행되어 그 안의 전화번호
/// 등록 팝업이 홈 화면 위로 떠버린 것이었다(B2, 리뷰에서 "D11보다 나쁘다"고
/// 지적됨). 그래서 이 테스트를 AppShell 레벨로 바꿔, 방문하지 않은 탭은
/// 실제로 만들어지지 않는지(따라서 그 안의 initState도 실행되지 않는지)를
/// 검증한다.
void main() {
  testWidgets(
    '홈 탭으로 시작하면 다른 탭(가족 탭)의 initState가 실행되지 않아 '
    '팝업이 뜨지 않는다 — 가족 탭을 방문한 뒤에야 뜬다(B2)',
    (tester) async {
      final builders = testPageBuilders();
      builders[AppShellTab.family] = (context, args) =>
          const DialogOnInitPage(tag: 'family');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: AppShell(initialIndex: AppShellTab.home, pageBuilders: builders),
        ),
      );
      // 로그인 직후 콜드 스타트에 해당하는 초기 프레임들만 확인한다 — B2로
      // 인해 재발했던 버그는 여기서 이미 나타난다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('family-popup'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // 사용자가 실제로 가족 탭을 열면, 그때는(오직 그때만) 팝업이 뜬다.
      final shellState = tester.state<AppShellState>(find.byType(AppShell));
      shellState.switchTab(AppShellTab.family);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('family-popup'), findsOneWidget);
    },
  );
}
