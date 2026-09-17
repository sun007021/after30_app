import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

const _options = [
  AppSegmentedOption(value: 'male', label: '남'),
  AppSegmentedOption(value: 'female', label: '여'),
];

void main() {
  testWidgets('iOS에서는 CupertinoSlidingSegmentedControl로 렌더링된다', (tester) async {
    String? selected;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSegmentedControl<String>(
          options: _options,
          value: 'male',
          onChanged: (v) => selected = v,
        ),
      ),
    );

    expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsOneWidget);
    await tester.tap(find.text('여'));
    await tester.pumpAndSettle();
    expect(selected, 'female');
  });

  testWidgets('Android에서는 기존 라디오 스타일로 렌더링된다', (tester) async {
    String? selected;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppSegmentedControl<String>(
          options: _options,
          value: 'male',
          onChanged: (v) => selected = v,
        ),
      ),
    );

    expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsNothing);
    expect(find.text('남'), findsOneWidget);
    expect(find.text('여'), findsOneWidget);

    await tester.tap(find.text('여'));
    await tester.pump();
    expect(selected, 'female');
  });
}
