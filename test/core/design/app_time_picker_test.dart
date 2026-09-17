import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 휠 피커 바텀시트를 띄우고 완료를 누르면 선택값을 반환한다', (tester) async {
    TimeOfDay? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '시간 선택',
          onPressed: () async {
            result = await showAppTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
          },
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
  });

  testWidgets('iOS에서 취소를 누르면 null을 반환한다', (tester) async {
    TimeOfDay? result = const TimeOfDay(hour: 1, minute: 1);
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '시간 선택',
          onPressed: () async {
            result = await showAppTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
          },
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('Android에서는 CupertinoDatePicker를 쓰지 않는다(Material showTimePicker)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => AppButton(
          label: '시간 선택',
          onPressed: () => showAppTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0)),
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
    // Material 기본 TimePickerDialog가 뜬다.
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
