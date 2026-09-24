import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';

import 'home_test_utils.dart';

/// 리뷰 M3: 진행 중이던(느린) 응답이 그사이 나간 더 최신 요청의 응답보다
/// 늦게 도착해도, 화면은 최신 요청의 결과를 유지해야 한다("최신 요청 승리").
void main() {
  testWidgets('오래된 응답이 늦게 도착해도 최신 요청(다음 날) 결과를 덮어쓰지 않는다', (tester) async {
    final pending = <DateTime, Completer<List<Medication>>>{};
    var first = true;
    Future<List<Medication>> fetch(DateTime start, DateTime end) {
      if (first) {
        // 초기 로드(오늘)는 즉시 끝낸다.
        first = false;
        return Future.value([fakeMedication(time: '09:00', date: start, name: '초기')]);
      }
      final completer = Completer<List<Medication>>();
      pending[DateTime(start.year, start.month, start.day)] = completer;
      return completer.future;
    }

    final key = GlobalKey<HomeContentState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          key: key,
          user: null,
          fetchMedications: fetch,
          familyService: FakeFamilyService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final t1 = t0.add(const Duration(days: 1));

    // 탭 재활성화로 "오늘" 재조회를 시작한다(응답은 아직 안 옴) →
    // 그 사이 사용자가 다음 날로 넘어간다(두 번째 요청 발생).
    unawaited(key.currentState!.onTabActivated());
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton)).last,
    );
    await tester.pump();

    // 최신 요청(다음 날)이 먼저 도착하고,
    pending[t1]!.complete([fakeMedication(time: '10:00', date: t1, name: '다음날')]);
    await tester.pump();
    // 오래된 요청(오늘)이 그 뒤에 늦게 도착한다.
    pending[t0]!.complete([fakeMedication(time: '09:00', date: t0, name: '오래된응답')]);
    await tester.pumpAndSettle();

    final selected = tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate;
    final names = tester
        .widgetList<MedicationDoseTile>(find.byType(MedicationDoseTile))
        .map((t) => t.medication.name)
        .toList();

    expect(selected, t1);
    expect(names, ['다음날']);
    expect(names, isNot(contains('오래된응답')));
  });
}
