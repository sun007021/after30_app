import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
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

  testWidgets('show()는 Android에서 배리어를 탭해도 닫히지 않는다(barrierDismissible false)', (tester) async {
    bool? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await DoubleCheckDialog.show(context: context, title: '복용 완료', message: '기록하시겠습니까?');
          },
          child: const Text('열기'),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // 다이얼로그 바깥(배리어)을 탭한다.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('show()는 Android에서 취소를 누르면 false를 반환한다', (tester) async {
    bool? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await DoubleCheckDialog.show(context: context, title: '복용 완료', message: '기록하시겠습니까?');
          },
          child: const Text('열기'),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('show()는 Android에서 확인 버튼 배경이 0xFF1963FF이다', (tester) async {
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

    final confirmButton = tester.widget<ElevatedButton>(
      find.ancestor(of: find.text('완료'), matching: find.byType(ElevatedButton)),
    );
    final backgroundColor = confirmButton.style?.backgroundColor?.resolve({});
    expect(backgroundColor, AppColors.primary);
    expect(AppColors.primary.toARGB32(), 0xFF1963FF);
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
