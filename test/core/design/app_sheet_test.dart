import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('그래버와 내용을 표시하고 값을 반환한다', (tester) async {
    String? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '시트 열기',
          onPressed: () async {
            result = await showAppSheet<String>(
              context: context,
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).pop('done'),
                child: const Text('닫기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('시트 열기'));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });

  testWidgets('Android에서도 그래버와 내용을 표시하고 값을 반환한다', (tester) async {
    String? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => AppButton(
          label: '시트 열기',
          onPressed: () async {
            result = await showAppSheet<String>(
              context: context,
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).pop('done'),
                child: const Text('닫기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('시트 열기'));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });
}
