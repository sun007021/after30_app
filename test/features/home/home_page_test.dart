import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';

import '../../core/design/design_test_utils.dart';
import 'home_test_utils.dart';

void main() {
  testWidgets('Android에서는 기존처럼 SingleChildScrollView 기반 레이아웃을 그대로 쓴다', (tester) async {
    final fetcher = CountingFetcher();

    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      HomePage(fetchMedications: fetcher.call, familyService: FakeFamilyService()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(AppSliverNavBar), findsNothing);
    expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
  });

  testWidgets('iOS에서는 큰 제목 헤더(AppSliverNavBar)와 당겨서 새로고침을 쓴다', (tester) async {
    final fetcher = CountingFetcher();

    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      HomePage(fetchMedications: fetcher.call, familyService: FakeFamilyService()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(AppSliverNavBar), findsOneWidget);
    // CupertinoSliverRefreshControl은 정지 상태에서 레이아웃 익스텐트가
    // 0이라 기본 파인더가 "화면 밖"으로 취급한다 — skipOffstage: false로
    // 확인한다.
    expect(
      find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      findsOneWidget,
    );
    // 오늘 날짜가 선택된 초기 상태이므로 큰 제목은 "오늘"로 표시된다.
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('복용 완료 확인은 여전히 DoubleCheckDialog(적응형 확인창)를 거친다', (tester) async {
    final fetcher = CountingFetcher(
      () => [fakeMedication(time: '09:00', date: DateTime.now())],
    );

    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      HomePage(fetchMedications: fetcher.call, familyService: FakeFamilyService()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MedicationDoseTile), findsOneWidget);
    await tester.tap(find.text('복용 완료'));
    await tester.pumpAndSettle();

    // 적응형 확인창(iOS: CupertinoAlertDialog)이 뜬다.
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  });
}
