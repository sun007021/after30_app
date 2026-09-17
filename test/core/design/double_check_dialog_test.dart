import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('show()는 iOS에서 CupertinoAlertDialog로 표시되고 완료 시 true를 반환한다', (tester) async {
    bool? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await DoubleCheckDialog.show(
              context: context,
              title: '복용 완료',
              message: '기록하시겠습니까?',
            );
          },
          child: const Text('열기'),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('show()는 Android에서 기존 AlertDialog 외형을 유지한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => DoubleCheckDialog.show(context: context, title: '복용 완료', message: '기록하시겠습니까?'),
          child: const Text('열기'),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });

  testWidgets('showSingle()은 확인 버튼 하나만 있는 알럿을 띄운다(Android)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => DoubleCheckDialog.showSingle(context: context, title: '오류', message: '다시 시도해 주세요'),
          child: const Text('열기'),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });
}
