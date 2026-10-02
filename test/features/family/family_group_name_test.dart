import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/ui/family_group_manage_page.dart';
import 'package:after30/features/family/ui/family_invite_group_name_page.dart';

import 'family_test_utils.dart';

Future<FakeFamilyService> _pumpManage(WidgetTester tester, TargetPlatform platform) async {
  SharedPreferences.setMockInitialValues({});
  useTallPhoneViewport(tester);
  final service = FakeFamilyService(
    groups: [fakeGroup()],
    members: [fakeMember(), fakeMember(userId: 2, name: '엄마', role: 'MEMBER')],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: FamilyGroupManagePage(
        groupId: 1,
        groupName: '우리 가족',
        familyService: service,
        resolveCurrentUserId: (_) async => 1,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// §6 W8 3항 — 그룹 이름 입력/수정(100자 제한 유지).
void main() {
  testWidgets('iOS: 이름 수정은 텍스트 입력 알럿이고 100자 제한을 유지한다', (tester) async {
    final service = await _pumpManage(tester, TargetPlatform.iOS);

    await tester.tap(find.byType(SvgPicture).first);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('그룹 이름 수정'), findsOneWidget);
    final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
    expect(field.maxLength, 100);
    expect(field.controller!.text, '우리 가족');

    await tester.enterText(find.byType(CupertinoTextField), '새 이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.renamedTo, ['새 이름']);
    expect(find.text('새 이름'), findsOneWidget);
  });

  testWidgets('Android: 이름 수정 다이얼로그는 기존 모양 그대로다', (tester) async {
    final service = await _pumpManage(tester, TargetPlatform.android);

    await tester.tap(find.byType(SvgPicture).first);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, Colors.white);
    expect(dialog.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 100);
    expect(field.decoration!.hintText, '그룹 이름');

    await tester.enterText(find.byType(TextField), '새 이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.renamedTo, ['새 이름']);
  });

  testWidgets('iOS: 새 그룹 이름 입력은 AppTextField(100자 제한)', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
        home: const FamilyInviteGroupNamePage(),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<AppTextField>(find.byType(AppTextField));
    expect(field.maxLength, 100);
    expect(field.placeholder, '최가족');
  });

  testWidgets('Android: 새 그룹 이름 입력은 기존 TextField 그대로', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.android),
        home: const FamilyInviteGroupNamePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppTextField), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, '최가족');
    expect(field.decoration!.fillColor, Colors.white);
    expect(field.maxLength, isNull);
  });
}
