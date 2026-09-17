import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 CupertinoTextField 기반으로 렌더링된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      const Material(child: AppTextField(placeholder: '이름')),
    );
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  testWidgets('Android에서는 기존 TextField로 렌더링된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      const Material(child: AppTextField(placeholder: '이름')),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
  });

  testWidgets('iOS에서 입력값이 있으면 clear 버튼이 나타나고 탭하면 비워진다', (tester) async {
    final controller = TextEditingController(text: '홍길동');
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(child: AppTextField(controller: controller)),
    );

    expect(find.byIcon(CupertinoIcons.clear_circled_solid), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
    await tester.pump();
    expect(controller.text, isEmpty);
  });

  testWidgets('숫자패드 + showKeyboardDoneBar가 켜져 있고 포커스가 있으면 iOS에서 완료 바가 보인다', (tester) async {
    final focusNode = FocusNode();
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppTextField(
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          showKeyboardDoneBar: true,
        ),
      ),
    );

    expect(find.text('완료'), findsNothing);
    focusNode.requestFocus();
    await tester.pump();
    expect(find.text('완료'), findsOneWidget);

    focusNode.unfocus();
    await tester.pump();
    expect(find.text('완료'), findsNothing);
  });

  testWidgets('Android에서는 숫자패드여도 완료 바를 그리지 않는다', (tester) async {
    final focusNode = FocusNode();
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppTextField(
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          showKeyboardDoneBar: true,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(find.byType(KeyboardDoneBar), findsNothing);
  });

  testWidgets('showObscureToggle이 켜져 있으면 눈 아이콘으로 obscureText를 토글한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      const Material(
        child: AppTextField(obscureText: true, showObscureToggle: true),
      ),
    );

    expect(find.byIcon(CupertinoIcons.eye_slash_fill), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.eye_slash_fill));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.eye_fill), findsOneWidget);
  });
}
