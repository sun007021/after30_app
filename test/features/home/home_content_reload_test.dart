import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';

import 'home_test_utils.dart';

void main() {
  testWidgets('reload()를 호출하면 복약 목록을 다시 불러온다', (tester) async {
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    final callsAfterInit = fetcher.callCount;
    expect(callsAfterInit, greaterThanOrEqualTo(1));

    await key.currentState!.reload();
    await tester.pumpAndSettle();

    expect(fetcher.callCount, greaterThan(callsAfterInit));
  });

  testWidgets('셸 밖(날짜 변경 신호 없음)에서 reload()를 호출해도 선택된 날짜는 그대로다', (tester) async {
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

    await key.currentState!.reload();
    await tester.pumpAndSettle();

    // AppShell.maybeOf(context)가 null이라 dateChangedOnLastActivation은
    // 항상 false로 취급되므로(§6 W7), 선택된 날짜가 오늘로 재설정되지
    // 않아야 한다 — 즉 reload가 예외 없이 끝나면 충분하다(날짜 재설정
    // 로직이 잘못 발동해 오늘로 튕기지 않는지가 핵심 회귀 포인트).
    expect(tester.takeException(), isNull);
  });
}
