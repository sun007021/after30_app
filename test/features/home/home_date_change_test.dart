import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';

import 'home_test_utils.dart';

/// PR #33 재검토 m3', m7' 회귀 테스트.
void main() {
  Finder nextDayButton() => find
      .descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton))
      .last;

  Finder previousDayButton() => find
      .descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton))
      .first;

  List<String> tileNames(WidgetTester tester) => tester
      .widgetList<MedicationDoseTile>(find.byType(MedicationDoseTile))
      .map((t) => t.medication.name)
      .toList();

  DateTime selectedDate(WidgetTester tester) =>
      tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate;

  testWidgets('날짜를 옮긴 뒤 새 날짜 조회가 실패하면 이전 날짜의 약 목록을 보여주지 않는다(m3\')', (tester) async {
    var first = true;
    Future<List<Medication>> fetch(DateTime start, DateTime end) {
      if (first) {
        first = false;
        return Future.value([fakeMedication(time: '09:00', date: start, name: '오늘약')]);
      }
      return Future.error(Exception('network down'));
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          user: null,
          fetchMedications: fetch,
          familyService: FakeFamilyService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tileNames(tester), ['오늘약']);

    await tester.tap(nextDayButton());
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    expect(selectedDate(tester), tomorrow);
    // 헤더는 다음 날인데 목록에 오늘 약이 남아 있으면, 여기서 "복용 완료"를
    // 누를 때 다른 날짜로 기록된다.
    expect(tileNames(tester), isNot(contains('오늘약')));
  });

  testWidgets('자정 이후 사용자가 직접 고른 날짜는 다음 탭 재활성화에서 되돌리지 않는다(m7\')', (tester) async {
    var now = DateTime(2026, 9, 24, 23, 50);
    Future<List<Medication>> fetch(DateTime start, DateTime end) =>
        Future.value([fakeMedication(time: '09:00', date: start, name: '약')]);

    final key = GlobalKey<HomeContentState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          key: key,
          user: null,
          now: () => now,
          fetchMedications: fetch,
          familyService: FakeFamilyService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selectedDate(tester), DateTime(2026, 9, 24));

    // 앱을 켜 둔 채 자정이 지났다(탭 재활성화는 아직 없음). 화면은 여전히
    // 9/24를 보여준다.
    now = DateTime(2026, 9, 25, 0, 10);

    // 사용자가 자정 이후에 직접 날짜를 옮긴다: 9/24 → 9/23.
    await tester.tap(previousDayButton());
    await tester.pumpAndSettle();
    expect(selectedDate(tester), DateTime(2026, 9, 23));

    // 다른 탭에 갔다가 돌아온다. 자정은 사용자가 날짜를 고르기 전에 이미
    // 지났으므로, 사용자가 고른 9/23을 오늘로 되돌리면 안 된다.
    unawaited(key.currentState!.onTabActivated());
    await tester.pumpAndSettle();
    expect(selectedDate(tester), DateTime(2026, 9, 23));
  });
}
