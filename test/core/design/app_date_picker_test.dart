import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS date 모드: 완료를 누르면 선택값을 반환한다', (tester) async {
    DateTime? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () async {
            result = await showAppDatePicker(context: context, initial: DateTime(2026, 1, 1));
          },
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
  });

  testWidgets('iOS monthYear 모드로 호출할 수 있다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '월 선택',
          onPressed: () => showAppDatePicker(
            context: context,
            initial: DateTime(2026, 1, 1),
            mode: AppDatePickerMode.monthYear,
          ),
        ),
      ),
    );

    await tester.tap(find.text('월 선택'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.mode, CupertinoDatePickerMode.monthYear);
  });

  testWidgets('initial이 min보다 이전이면 min으로 클램프된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () => showAppDatePicker(
            context: context,
            initial: DateTime(2020, 1, 1),
            min: DateTime(2025, 6, 1),
            max: DateTime(2030, 1, 1),
          ),
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.initialDateTime, DateTime(2025, 6, 1));
  });

  testWidgets('initial이 max보다 이후면 max로 클램프된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () => showAppDatePicker(
            context: context,
            initial: DateTime(2035, 1, 1),
            min: DateTime(2020, 1, 1),
            max: DateTime(2030, 1, 1),
          ),
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.initialDateTime, DateTime(2030, 1, 1));
  });

  testWidgets('min과 max가 모두 DateTime.now()여도(시각 차이) 예외 없이 동작한다', (tester) async {
    // DateTime.now()를 각각 다른 시점에 호출하면 시/분/초/밀리초가 달라져
    // min > max 처럼 보일 수 있다(레이스). 날짜 단위로 정규화하면 같은
    // 날짜이므로 문제없이 동작해야 한다.
    final now1 = DateTime.now();
    final now2 = DateTime.now();
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () => showAppDatePicker(context: context, initial: now1, min: now1, max: now2),
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('Android에서도 initial이 범위를 벗어나면 클램프된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () => showAppDatePicker(
            context: context,
            initial: DateTime(2020, 1, 1),
            min: DateTime(2025, 6, 1),
            max: DateTime(2030, 1, 1),
          ),
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(dialog.initialDate, DateTime(2025, 6, 1));
  });

  testWidgets('Android에서는 Material DatePickerDialog를 띄운다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => AppButton(
          label: '날짜 선택',
          onPressed: () => showAppDatePicker(context: context, initial: DateTime(2026, 1, 1)),
        ),
      ),
    );

    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
