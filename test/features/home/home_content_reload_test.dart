import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';

import 'home_test_utils.dart';

/// 테스트에서 자유롭게 앞뒤로 돌릴 수 있는 가짜 시계(리뷰 M1). 실제
/// [AppShell]의 전역 플래그 대신, 화면이 직접 주입받는 시계와 비교해 자정
/// 롤오버를 판단하므로 이렇게 결정론적으로 재현할 수 있다.
class _FakeClock {
  _FakeClock(this._value);
  DateTime _value;
  DateTime call() => _value;
  void advanceDays(int days) => _value = _value.add(Duration(days: days));
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

void main() {
  testWidgets('onTabActivated(): 날짜가 안 바뀌었으면 사용자가 고른 날짜가 유지된다(리뷰 M1/m7)', (tester) async {
    final clock = _FakeClock(_dateOnly(DateTime.now()));
    final fetcher = CountingFetcher();
    final key = GlobalKey<HomeContentState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          key: key,
          user: null,
          fetchMedications: fetcher.call,
          familyService: FakeFamilyService(),
          now: clock.call,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 하루 전으로 이동한다(첫 번째 아이콘 버튼 = 이전 날짜).
    final prevDayButton = find
        .descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton))
        .first;
    await tester.tap(prevDayButton);
    await tester.pumpAndSettle();
    final yesterday = clock._value.subtract(const Duration(days: 1));
    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, yesterday);

    final callsBefore = fetcher.callCount;
    await key.currentState!.onTabActivated();
    await tester.pumpAndSettle();

    // 시계가 그대로이므로(자정을 넘기지 않았으므로) 선택 날짜는 유지되고,
    // 다만 데이터는 다시 불러왔어야 한다.
    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, yesterday);
    expect(fetcher.callCount, greaterThan(callsBefore));
  });

  testWidgets('onTabActivated(): 자정이 지났으면 선택 날짜가 오늘로 재설정된다(리뷰 M1)', (tester) async {
    final clock = _FakeClock(_dateOnly(DateTime.now()));
    final fetcher = CountingFetcher();
    final key = GlobalKey<HomeContentState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          key: key,
          user: null,
          fetchMedications: fetcher.call,
          familyService: FakeFamilyService(),
          now: clock.call,
        ),
      ),
    );
    await tester.pumpAndSettle();

    clock.advanceDays(1);
    await key.currentState!.onTabActivated();
    await tester.pumpAndSettle();

    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, clock._value);
  });

  testWidgets('refresh()(당겨서 새로고침)는 자정이 지났어도 사용자가 고른 날짜를 바꾸지 않는다(리뷰 M2)', (tester) async {
    final clock = _FakeClock(_dateOnly(DateTime.now()));
    final fetcher = CountingFetcher();
    final key = GlobalKey<HomeContentState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: HomeContent(
          key: key,
          user: null,
          fetchMedications: fetcher.call,
          familyService: FakeFamilyService(),
          now: clock.call,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final prevDayButton = find
        .descendant(of: find.byType(HomeDateHeader), matching: find.byType(IconButton))
        .first;
    await tester.tap(prevDayButton);
    await tester.pumpAndSettle();
    final yesterday = clock._value.subtract(const Duration(days: 1));
    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, yesterday);

    // 자정이 지난 상태를 흉내낸다. onTabActivated()가 아직 호출되지
    // 않았어도(예: 사용자가 아직 이 탭을 벗어나지 않음) 당겨서 새로고침은
    // 절대 날짜를 되돌리면 안 된다.
    clock.advanceDays(1);
    await key.currentState!.refresh();
    await tester.pumpAndSettle();

    expect(tester.widget<HomeDateHeader>(find.byType(HomeDateHeader)).selectedDate, yesterday);
  });
}
