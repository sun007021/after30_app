import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';

import '../../app/app_shell_test_utils.dart';
import 'calendar_test_utils.dart';

/// §6 W7 — 기록(캘린더) 탭이 다시 활성화되면 최신 데이터를 다시 불러와야
/// 한다(R3 공통 규칙, M2 훅). 예: 홈 탭에서 복용 완료로 기록한 뒤 기록
/// 탭으로 돌아오면 최신 상태가 반영돼야 한다.
void main() {
  testWidgets('다른 탭에 갔다가 기록 탭으로 돌아오면 복약 목록을 다시 불러온다(M2)', (tester) async {
    final fetcher = CountingFetcher();
    final builders = testPageBuilders();
    builders[AppShellTab.history] =
        (context, args) => CalendarPage(fetchMedications: fetcher.call);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: AppShell(initialIndex: AppShellTab.history, pageBuilders: builders),
      ),
    );
    await tester.pumpAndSettle();

    final initialCalls = fetcher.callCount;
    expect(initialCalls, greaterThanOrEqualTo(1));

    final shellState = tester.state<AppShellState>(find.byType(AppShell));
    shellState.switchTab(AppShellTab.home);
    await tester.pumpAndSettle();
    shellState.switchTab(AppShellTab.history);
    await tester.pumpAndSettle();

    expect(fetcher.callCount, greaterThan(initialCalls));
  });
}
