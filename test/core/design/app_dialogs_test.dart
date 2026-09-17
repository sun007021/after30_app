import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  group('showAppAlert', () {
    testWidgets('iOS에서는 CupertinoAlertDialog를 띄운다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () => showAppAlert(context: context, title: '안내', message: '내용'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    });

    testWidgets('Android에서는 기존 AlertDialog를 띄운다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () => showAppAlert(context: context, title: '안내', message: '내용'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('showAppConfirm', () {
    testWidgets('확인을 누르면 true를 반환한다(iOS)', (tester) async {
      bool? result;
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () async {
              result = await showAppConfirm(context: context, title: '확인', message: '진행할까요?');
            },
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('취소를 누르면 false를 반환한다(Android)', (tester) async {
      bool? result;
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () async {
              result = await showAppConfirm(context: context, title: '확인', message: '진행할까요?');
            },
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('showAppActionSheet', () {
    testWidgets('iOS에서는 CupertinoActionSheet를 띄우고 선택값을 반환한다', (tester) async {
      String? result;
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () async {
              result = await showAppActionSheet<String>(
                context: context,
                actions: const [AppActionSheetAction(label: '삭제', value: 'delete', destructive: true)],
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(result, 'delete');
    });
  });

  group('showAppTextInputAlert', () {
    testWidgets('입력한 텍스트를 반환한다', (tester) async {
      String? result;
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        Builder(
          builder: (context) => AppButton(
            label: '열기',
            onPressed: () async {
              result = await showAppTextInputAlert(context: context, title: '그룹 이름', initialValue: '우리 가족');
            },
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '새 이름');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(result, '새 이름');
    });
  });
}
