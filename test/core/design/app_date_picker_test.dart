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
