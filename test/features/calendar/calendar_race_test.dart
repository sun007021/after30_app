import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_day_widgets.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_month_header.dart';

import 'calendar_test_utils.dart';

/// 리뷰 M3: 이전 달(느린) 응답이 그 사이 사용자가 넘어간 다음 달(빠른)
/// 응답보다 늦게 도착해도, 화면은 지금 보고 있는 달의 결과를 유지해야
/// 한다. 응답 경쟁 가드가 없으면 늦게 도착한 다음 달 응답이
/// `..clear()..addAll(...)`로 이번 달 데이터를 통째로 지워버린다.
void main() {
  testWidgets('오래된 달 응답이 늦게 도착해도 지금 보고 있는 달의 게이지를 지우지 않는다', (tester) async {
    final pending = <DateTime, Completer<List<Medication>>>{};
    var first = true;
    Future<List<Medication>> fetch(DateTime start, DateTime end) {
      if (first) {
        first = false;
        return Future.value(const []);
      }
      final key = DateTime(start.year, start.month);
      final completer = Completer<List<Medication>>();
      pending[key] = completer;
      return completer.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: CalendarPage(fetchMedications: fetch),
      ),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    // 오늘이 아닌 날(선택된 날은 게이지 렌더링 규칙이 달라 신호가
    // 흐려진다)에 미완료 복약 1건을 둬서 GaugeDay로 렌더링되게 한다.
    final markedDay = now.day == 1
        ? DateTime(now.year, now.month, 2)
        : DateTime(now.year, now.month, 1);

    final monthButtons =
        find.descendant(of: find.byType(CalendarMonthHeader), matching: find.byType(IconButton));
    final prevButton = monthButtons.first;
    final nextButton = monthButtons.last;

    // 다음 달로 이동한다(요청 발생, 아직 응답 없음) → 다시 이번 달(현재
    // 보고 있던 달)로 돌아온다(두 번째 요청 발생).
    await tester.tap(nextButton);
    await tester.pump();
    await tester.tap(prevButton);
    await tester.pump();

    // 최신 요청(이번 달)이 먼저 도착하고,
    pending[thisMonth]!.complete([fakeMedication(time: '09:00', date: markedDay, name: '이번달')]);
    await tester.pump();
    // 오래된 요청(다음 달)이 그 뒤에 늦게 도착한다.
    pending[nextMonth]!.complete([fakeMedication(time: '09:00', date: nextMonth, name: '다음달')]);
    await tester.pumpAndSettle();

    expect(
      tester.widget<CalendarMonthHeader>(find.byType(CalendarMonthHeader)).focusedDay.month,
      thisMonth.month,
    );
    // 응답 경쟁 가드가 없다면 늦게 도착한 다음 달 응답이 이번 달 게이지를
    // 지워버려 GaugeDay가 하나도 남지 않는다.
    expect(find.byType(GaugeDay), findsWidgets);
  });
}
