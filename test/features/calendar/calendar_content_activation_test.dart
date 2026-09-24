import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_month_header.dart';
import 'package:after30/features/calendar/ui/widgets/medication_sheet_header.dart';

import 'calendar_test_utils.dart';

/// 테스트에서 자유롭게 앞뒤로 돌릴 수 있는 가짜 시계(리뷰 M1). 캘린더
/// 화면이 `AppShell.dateChangedOnLastActivation`(셸 전역 플래그) 대신
/// 스스로 주입받은 시계로 자정 롤오버를 판단하는지 결정론적으로 검증한다.
class _FakeClock {
  _FakeClock(this.value);
  DateTime value;
  DateTime call() => value;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

void main() {
  testWidgets('onTabActivated(): 날짜가 안 바뀌었으면 선택 날짜/달이 유지된다(리뷰 M1)', (tester) async {
    final clock = _FakeClock(_dateOnly(DateTime.now()));
    final fetcher = CountingFetcher();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: CalendarPage(fetchMedications: fetcher.call, now: clock.call),
      ),
    );
    await tester.pumpAndSettle();

    final beforeMonth = tester.widget<CalendarMonthHeader>(find.byType(CalendarMonthHeader)).focusedDay;
    final callsBefore = fetcher.callCount;

    // ignore: avoid_dynamic_calls
    await (tester.state(find.byType(CalendarPage)) as dynamic).onTabActivated();
    await tester.pumpAndSettle();

    final afterMonth = tester.widget<CalendarMonthHeader>(find.byType(CalendarMonthHeader)).focusedDay;
    expect(afterMonth.year, beforeMonth.year);
    expect(afterMonth.month, beforeMonth.month);
    expect(fetcher.callCount, greaterThan(callsBefore));
  });

  testWidgets('onTabActivated(): 자정이 지났으면 선택 날짜가 오늘로 재설정된다(리뷰 M1)', (tester) async {
    final clock = _FakeClock(_dateOnly(DateTime.now()));
    final fetcher = CountingFetcher();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: CalendarPage(fetchMedications: fetcher.call, now: clock.call),
      ),
    );
    await tester.pumpAndSettle();

    clock.value = clock.value.add(const Duration(days: 1));
    // ignore: avoid_dynamic_calls
    await (tester.state(find.byType(CalendarPage)) as dynamic).onTabActivated();
    await tester.pumpAndSettle();

    final header = tester.widget<CalendarMonthHeader>(find.byType(CalendarMonthHeader)).focusedDay;
    expect(header.year, clock.value.year);
    expect(header.month, clock.value.month);

    final expectedDateText =
        '${clock.value.year.toString().padLeft(4, '0')}.${clock.value.month.toString().padLeft(2, '0')}.${clock.value.day.toString().padLeft(2, '0')}';
    expect(
      tester
          .widgetList<MedicationSheetHeader>(find.byType(MedicationSheetHeader))
          .any((w) => w.selectedDay != null && _dateOnly(w.selectedDay!) == clock.value),
      isTrue,
      reason: '선택된 날짜 표시가 새 "오늘"($expectedDateText)로 바뀌어야 한다',
    );
  });
}
