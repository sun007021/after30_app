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

  testWidgets('iOS에서 스크롤 없이 완료를 누르면 초기값이 그대로 반환된다', (tester) async {
    TimeOfDay? result;
    const initial = TimeOfDay(hour: 8, minute: 30);
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '시간 선택',
          onPressed: () async {
            result = await showAppTimePicker(context: context, initialTime: initial);
          },
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(result, initial);
  });

  testWidgets('기기 설정이 24시간 표기이면 CupertinoDatePicker에 use24hFormat이 전달된다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(alwaysUse24HourFormat: true),
        child: MaterialApp(
          theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => AppButton(
              label: '시간 선택',
              onPressed: () => showAppTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0)),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.use24hFormat, isTrue);
  });

  testWidgets('기기 설정이 12시간 표기이면 CupertinoDatePicker에 use24hFormat=false가 전달된다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(alwaysUse24HourFormat: false),
        child: MaterialApp(
          theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => AppButton(
              label: '시간 선택',
              onPressed: () => showAppTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0)),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('시간 선택'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(picker.use24hFormat, isFalse);
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
