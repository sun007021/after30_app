import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_day_widgets.dart';

import '../../core/design/design_test_utils.dart';
import 'calendar_test_utils.dart';

void main() {
  Material sheetMaterial(WidgetTester tester) {
    return tester.widget<Material>(
      find.byWidgetPredicate(
        (w) => w is Material && w.clipBehavior == Clip.antiAlias && w.color == Colors.white,
      ),
    );
  }

  testWidgets('Android 기록 시트는 기존 사각 곡률(20)과 헤어라인 테두리를 유지한다', (tester) async {
    final fetcher = CountingFetcher();
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    final shape = sheetMaterial(tester).shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.vertical(top: Radius.circular(20)));
    expect(shape.side.width, 1);
  });

  testWidgets('iOS 기록 시트는 토큰 상단 곡률(AppRadius.xl, 연속 곡률)을 테두리 없이 쓴다', (tester) async {
    final fetcher = CountingFetcher();
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    final shape = sheetMaterial(tester).shape as RoundedSuperellipseBorder;
    expect(shape.borderRadius, BorderRadius.vertical(top: Radius.circular(28)));
    expect(shape.side, BorderSide.none);
  });

  testWidgets('월 제목을 탭하면 연/월 점프 피커가 뜬다(iOS: 휠 피커)', (tester) async {
    final fetcher = CountingFetcher();
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final title = '${now.year}년 ${now.month.toString().padLeft(2, '0')}월';
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('월 제목 탭은 iOS 전용이다 — Android는 탭 핸들러가 없다(리뷰 m1)', (tester) async {
    final fetcher = CountingFetcher();
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final title = '${now.year}년 ${now.month.toString().padLeft(2, '0')}월';
    // 기존 구조 그대로: 제목 위에 GestureDetector가 씌워지지 않는다.
    expect(
      find.ancestor(of: find.text(title), matching: find.byType(GestureDetector)),
      findsNothing,
    );

    await tester.tap(find.text(title), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('fetchMedications를 주입하면 실제 네트워크 대신 그 함수를 쓴다', (tester) async {
    final fetcher = CountingFetcher(
      () => [fakeMedication(time: '09:00', date: DateTime.now())],
    );
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    expect(fetcher.callCount, greaterThanOrEqualTo(1));
  });

  testWidgets('iOS: 미완료인 선택 날짜는 채움 원이 아니라 테두리 원이다(완료 표시와 구분)', (tester) async {
    // 꽉 찬 파란 원은 "그날 약을 모두 복용"이라는 뜻이다. 선택만으로
    // 채우면 반만 복용한 날이 완료처럼 보이므로, iOS도 미완료 선택일은
    // 테두리 원이어야 한다(2026-09-25 결정). 오늘은 초기값으로 이미
    // 선택돼 있다.
    final fetcher = CountingFetcher(
      () => [
        fakeMedication(time: '09:00', date: DateTime.now(), status: 'pending'),
      ],
    );
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledDay), findsNothing);
    expect(find.byType(OutlinedDay), findsWidgets);
  });

  testWidgets('Android: 미완료인 선택 날짜는 기존처럼 테두리 원으로 남는다(리뷰 m6 대조군)', (tester) async {
    final fetcher = CountingFetcher(
      () => [
        fakeMedication(time: '09:00', date: DateTime.now(), status: 'pending'),
      ],
    );
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      CalendarPage(fetchMedications: fetcher.call),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilledDay), findsNothing);
    expect(find.byType(OutlinedDay), findsWidgets);
  });
}
