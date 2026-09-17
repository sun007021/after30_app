import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 SnackBar 대신 글래스 배너로 메시지를 띄운다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(
        body: Builder(
          builder: (context) => AppButton(
            label: '토스트',
            onPressed: () => AppToast.show(context, '완료되었습니다.', type: AppToastType.success),
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트'));
    await tester.pump();
    expect(find.text('완료되었습니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // 배너는 2.5초 뒤 스스로 사라진다(Future.delayed). 테스트 종료 시
    // "pending timer" 오류가 나지 않도록 타이머가 실행될 때까지 진행한다.
    await tester.pump(const Duration(milliseconds: 2600));
  });

  testWidgets('Android에서는 기존 SnackBar로 메시지를 띄운다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Scaffold(
        body: Builder(
          builder: (context) => AppButton(
            label: '토스트',
            onPressed: () => AppToast.show(context, '완료되었습니다.'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
