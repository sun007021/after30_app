import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/home/ui/home.dart';

import '../../app/app_shell_test_utils.dart';
import 'home_test_utils.dart';

/// §6 W7 — 홈 탭이 (다른 탭에 있다가) 다시 활성화되면 최신 복약 데이터를
/// 다시 불러와야 한다(R3 공통 규칙, M2 훅). [AppShell]의 주입 가능한
/// `pageBuilders`로 실제 [HomePage]를 홈 탭에 꽂고, 나머지 탭은 가벼운
/// 스텁으로 채워 탭 전환만으로 재조회가 일어나는지 확인한다.
void main() {
  testWidgets('다른 탭에 갔다가 홈 탭으로 돌아오면 복약 목록을 다시 불러온다(M2)', (tester) async {
    final fetcher = CountingFetcher();
    final builders = testPageBuilders();
    builders[AppShellTab.home] = (context, args) => HomePage(
          fetchMedications: fetcher.call,
          familyService: FakeFamilyService(),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: AppShell(initialIndex: AppShellTab.home, pageBuilders: builders),
      ),
    );
    await tester.pumpAndSettle();

    final initialCalls = fetcher.callCount;
    expect(initialCalls, greaterThanOrEqualTo(1));

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.alarm);
    await tester.pumpAndSettle();
    shellState.switchTab(AppShellTab.home);
    await tester.pumpAndSettle();

    expect(fetcher.callCount, greaterThan(initialCalls));
  });
}
