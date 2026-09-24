import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_month_header.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';

import '../../app/app_shell_test_utils.dart';
import 'home_test_utils.dart';

/// 리뷰 M1 재현 시나리오(정확히 리뷰가 지적한 순서): 홈에서 어제를 고르고
/// → 기록 탭으로 이동 → 기록 탭에 있는 동안 자정이 지남(앱 재개) → 홈으로
/// 돌아옴. 셸 전역 `dateChangedOnLastActivation` 플래그에 의존했을 때는
/// "재개 시점에 활성 탭이었던 기록 탭만" 리셋되고, 그 뒤 홈으로 돌아오면
/// 플래그가 이미 false로 소비돼 있어 홈은 계속 어제에 머물렀다. 각 화면이
/// 자기 시계로 스스로 판단하는 지금은 어느 탭에 있었든, 다음에 활성화되는
/// 순간 정확히 리셋된다.
void main() {
  testWidgets('기록 탭에 있는 동안 자정이 지나도, 나중에 홈으로 돌아오면 홈이 오늘로 재설정된다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    DateTime clockValue = today;
    DateTime clock() => clockValue;

    final homeFetch = CountingFetcher();
    final calFetch = CountingFetcher();
    final builders = testPageBuilders();
    builders[AppShellTab.home] = (c, a) => HomePage(
          fetchMedications: homeFetch.call,
          familyService: FakeFamilyService(),
          now: clock,
        );
    builders[AppShellTab.history] = (c, a) => CalendarPage(fetchMedications: calFetch.call, now: clock);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: AppShell(initialIndex: AppShellTab.home, pageBuilders: builders),
      ),
    );
    await tester.pumpAndSettle();
    final shell = tester.state<AppShellState>(find.byType(AppShell));

    // 1) 홈에서 어제로 이동한다.
    await tester.tap(
      find.descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton)).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, today.subtract(const Duration(days: 1)));

    // 2) 기록 탭으로 전환한다(아직 롤오버 전).
    shell.switchTab(AppShellTab.history);
    await tester.pumpAndSettle();

    // 3) 기록 탭에 머무는 동안 자정이 지난다(앱 재개로 감지).
    clockValue = tomorrow;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    // 기록 탭(활성 탭)은 스스로 리셋해 오늘 달을 보여준다.
    expect(
      tester.widget<CalendarMonthHeader>(find.byType(CalendarMonthHeader)).focusedDay.month,
      tomorrow.month,
    );

    // 4) 홈으로 돌아온다 — 셸 전역 플래그는 이미 3)에서 소비됐지만, 홈은
    //    자기 시계로 직접 판단하므로 여전히 정확히 리셋돼야 한다(M1).
    shell.switchTab(AppShellTab.home);
    await tester.pumpAndSettle();

    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, tomorrow);
  });
}
