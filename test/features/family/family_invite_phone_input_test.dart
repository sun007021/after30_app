import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';

import 'family_test_utils.dart';

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  useTallPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: FamilyInviteExistingGroupInvitePage(
        groupId: 1,
        groupName: '우리 가족',
        familyService: FakeFamilyService(),
        profileService: FakeProfileService(phone: '010-1111-2222'),
        userService: FakeUserService(knownUsers: {
          '+821099998888': '아빠',
          '+821077776666': '엄마',
        }),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// §6 W8 2항 — 초대 번호 입력(전화 패드/완료 바/포매터/자동완성)과 캡슐 칩.
void main() {
  testWidgets('iOS: AppTextField(전화 패드, 완료 바, 포매터, 자동완성)와 추가 버튼', (tester) async {
    await _pump(tester, TargetPlatform.iOS);

    final field = tester.widget<AppTextField>(find.byType(AppTextField));
    expect(field.keyboardType, TextInputType.phone);
    expect(field.showKeyboardDoneBar, isTrue);
    expect(field.autofillHints, contains(AutofillHints.telephoneNumber));
    expect(field.inputFormatters!.whereType<PhoneNumberFormatter>(), isNotEmpty);

    await tester.tap(find.byType(EditableText).last);
    await tester.pump();
    expect(find.byType(KeyboardDoneBar), findsOneWidget);

    await tester.enterText(find.byType(EditableText).last, '01099998888');
    await tester.pump();
    expect(find.text('010-9999-8888'), findsOneWidget);
  });

  testWidgets('iOS: 번호를 추가하면 캡슐 칩이 생기고 x로 삭제된다', (tester) async {
    await _pump(tester, TargetPlatform.iOS);

    for (final raw in ['01099998888', '01077776666']) {
      await tester.enterText(find.byType(EditableText).last, raw);
      await tester.pump();
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
    }
    expect(find.text('아빠'), findsOneWidget);
    expect(find.text('엄마'), findsOneWidget);

    // 칩은 브랜드 틴트 캡슐이다.
    final chip = tester.widget<Container>(
      find.ancestor(of: find.text('아빠'), matching: find.byType(Container)).first,
    );
    final decoration = chip.decoration! as ShapeDecoration;
    expect(decoration.color, AppColors.primaryTint);
    expect(decoration.shape, isA<StadiumBorder>());

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill).first);
    await tester.pump();
    expect(find.text('아빠'), findsNothing);
    expect(find.text('엄마'), findsOneWidget);
  });

  testWidgets('Android: 기존 TextField 외형과 칩이 그대로다', (tester) async {
    await _pump(tester, TargetPlatform.android);

    expect(find.byType(AppTextField), findsNothing);
    expect(find.text('추가'), findsNothing);
    final phoneField = tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(phoneField.keyboardType, TextInputType.phone);
    expect(phoneField.inputFormatters, isNull);
    final deco = phoneField.decoration!;
    expect(deco.hintText, '010-XXXX-XXXX');
    expect(deco.fillColor, Colors.white);
    final border = deco.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(10));
    expect(border.borderSide.color, const Color(0xFFA4A4A4));

    await tester.enterText(find.byType(TextField).last, '01099998888');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final chip = tester.widget<Container>(
      find.ancestor(of: find.text('아빠'), matching: find.byType(Container)).first,
    );
    final box = chip.decoration! as BoxDecoration;
    expect(box.color, Colors.white);
    expect(box.borderRadius, BorderRadius.circular(20));
    expect(box.border, Border.all(color: Colors.black));
    expect(chip.constraints?.maxHeight, 31);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
