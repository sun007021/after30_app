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

  testWidgets('기본값은 iOS 플랫폼 기본 썸(흰색)을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSegmentedControl<String>(options: _options, value: 'male', onChanged: (_) {}),
      ),
    );
    final widget = tester.widget<CupertinoSlidingSegmentedControl<String>>(
      find.byType(CupertinoSlidingSegmentedControl<String>),
    );
    expect(widget.thumbColor, CupertinoColors.white);
  });

  testWidgets('tinted: true면 브랜드 컬러 썸을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSegmentedControl<String>(
          options: _options,
          value: 'male',
          onChanged: (_) {},
          tinted: true,
        ),
      ),
    );
    final widget = tester.widget<CupertinoSlidingSegmentedControl<String>>(
      find.byType(CupertinoSlidingSegmentedControl<String>),
    );
    expect(widget.thumbColor, AppColors.primary);
  });

  testWidgets('Android에서는 2개보다 많은 옵션도 표시할 수 있다', (tester) async {
    const options = [
      AppSegmentedOption(value: 'a', label: 'A'),
      AppSegmentedOption(value: 'b', label: 'B'),
      AppSegmentedOption(value: 'c', label: 'C'),
      AppSegmentedOption(value: 'd', label: 'D'),
    ];
    String? selected;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppSegmentedControl<String>(options: options, value: 'a', onChanged: (v) => selected = v),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(selected, 'c');
  });
}
