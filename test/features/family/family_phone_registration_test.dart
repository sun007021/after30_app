import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/features/family/ui/widgets/family_phone_banner.dart';

import 'family_test_utils.dart';

const _bannerText = '가족이 나를 초대하려면 전화번호가 필요해요';
const _sheetTitle = '전화번호를 등록해 주세요';

Future<void> _register(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(EditableText).last, input);
  await tester.pump();
  await tester.tap(find.text('등록하기').last);
  await tester.pumpAndSettle();
}

/// §6 W8 / D11 — 전화번호 등록은 가족 탭 진입 시 강제하지 않고, 필요한
/// 동작(그룹 생성/초대 전송/초대 수락) 직전에만 시트로 요구한다.
void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('D11 전화번호 유도 - $platform', () {
      testWidgets('번호가 없어도 가족 탭 진입 시 모달이 뜨지 않고 배너가 보인다', (tester) async {
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: FakeProfileService(),
        );

        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(_sheetTitle), findsNothing);
        expect(find.text(_bannerText), findsOneWidget);
        expect(find.byType(FamilyPhoneBanner), findsOneWidget);
        // 모달이 없으므로 탭에서 쫓겨나지도 않는다.
        expect(find.text('등록된 가족이 없어요'), findsOneWidget);
      });

      testWidgets('배너를 닫으면 사라진다', (tester) async {
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: FakeProfileService(),
        );

        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(find.text(_bannerText), findsNothing);
      });

      testWidgets('번호가 있으면 배너가 없다', (tester) async {
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: FakeProfileService(phone: '010-1234-5678'),
        );
        expect(find.text(_bannerText), findsNothing);
      });

      testWidgets('배너의 등록하기로 시트를 열어 등록하면 배너가 사라진다', (tester) async {
        final profile = FakeProfileService();
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: profile,
        );

        await tester.tap(find.text('등록하기'));
        await tester.pumpAndSettle();
        expect(find.text(_sheetTitle), findsOneWidget);

        await _register(tester, '01012345678');
        expect(profile.savedPhones, ['010-1234-5678']);
        expect(find.text(_sheetTitle), findsNothing);
        expect(find.text(_bannerText), findsNothing);
      });

      testWidgets('그룹 생성: 번호가 없으면 시트가 열리고, 등록 후 생성 화면으로 이어진다', (tester) async {
        final profile = FakeProfileService();
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: profile,
        );

        await tester.tap(find.text('새 그룹 생성하기'));
        await tester.pumpAndSettle();
        expect(find.text(_sheetTitle), findsOneWidget);
        expect(find.byType(FamilyInviteGroupSelectPage), findsNothing);

        await _register(tester, '010-1234-5678');
        expect(find.byType(FamilyInviteGroupSelectPage), findsOneWidget);
      });

      testWidgets('그룹 생성: 시트를 닫으면 진행되지 않는다', (tester) async {
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: FakeFamilyService(),
          profileService: FakeProfileService(),
        );

        await tester.tap(find.text('새 그룹 생성하기'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text(_sheetTitle), findsNothing);
        expect(find.byType(FamilyInviteGroupSelectPage), findsNothing);
      });

      testWidgets('초대 수락: 번호가 없으면 시트 후 수락이 이어진다', (tester) async {
        final family = FakeFamilyService(invitations: [fakeInvitation()]);
        final profile = FakeProfileService();
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: family,
          profileService: profile,
        );

        await tester.tap(find.text('수락하기'));
        await tester.pumpAndSettle();
        // 확인 팝업
        await tester.tap(find.text('수락하기').last);
        await tester.pumpAndSettle();
        expect(find.text(_sheetTitle), findsOneWidget);
        expect(family.acceptedInvitationIds, isEmpty);

        await _register(tester, '010-1234-5678');
        expect(family.acceptedInvitationIds, [5]);
      });

      testWidgets('초대 수락: 번호가 이미 있으면 시트 없이 바로 수락한다', (tester) async {
        final family = FakeFamilyService(invitations: [fakeInvitation()]);
        await pumpFamilyPage(
          tester,
          platform: platform,
          familyService: family,
          profileService: FakeProfileService(phone: '010-1234-5678'),
        );

        await tester.tap(find.text('수락하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('수락하기').last);
        await tester.pumpAndSettle();
        expect(find.text(_sheetTitle), findsNothing);
        expect(family.acceptedInvitationIds, [5]);
      });

      testWidgets('초대 전송: 번호가 없으면 시트 후 그룹 생성과 전송이 이어진다', (tester) async {
        final family = FakeFamilyService();
        final profile = FakeProfileService();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build().copyWith(platform: platform),
            home: FamilyInviteExistingGroupInvitePage(
              groupName: '새 가족',
              familyService: family,
              profileService: profile,
              userService: FakeUserService(knownUsers: {'+821099998888': '아빠'}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(EditableText).last, '01099998888');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('아빠'), findsOneWidget);

        await tester.tap(find.text('초대 하기'));
        await tester.pumpAndSettle();
        expect(find.text(_sheetTitle), findsOneWidget);
        expect(family.createdGroupNames, isEmpty);

        await _register(tester, '010-1234-5678');
        expect(family.createdGroupNames, ['새 가족']);
        expect(family.sentPhones, ['+821099998888']);
      });
    });
  }

  group('등록 시트', () {
    Future<void> openSheet(
      WidgetTester tester, {
      required TargetPlatform platform,
      required FakeProfileService profile,
      required FakeUserService users,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build().copyWith(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ensurePhoneRegistered(
                    context,
                    profileService: profile,
                    userService: users,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('iOS: 전화 키보드 + 하이픈 포매터 + 완료 바', (tester) async {
      await openSheet(
        tester,
        platform: TargetPlatform.iOS,
        profile: FakeProfileService(),
        users: FakeUserService(),
      );

      final field = tester.widget<AppTextField>(find.byType(AppTextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.showKeyboardDoneBar, isTrue);
      expect(field.autofillHints, contains(AutofillHints.telephoneNumber));
      expect(field.inputFormatters!.whereType<PhoneNumberFormatter>(), isNotEmpty);

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(find.byType(KeyboardDoneBar), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '01012345678');
      await tester.pump();
      expect(find.text('010-1234-5678'), findsOneWidget);
    });

    testWidgets('중복 번호면 오류를 보여주고 저장하지 않는다', (tester) async {
      final profile = FakeProfileService();
      await openSheet(
        tester,
        platform: TargetPlatform.iOS,
        profile: profile,
        users: FakeUserService(duplicatePhones: {'010-1234-5678'}),
      );

      await _register(tester, '010-1234-5678');
      expect(find.text('이미 사용 중인 번호입니다.'), findsOneWidget);
      expect(profile.savedPhones, isEmpty);
      expect(find.text(_sheetTitle), findsOneWidget);
    });

    testWidgets('형식이 틀리면 오류를 보여준다', (tester) async {
      final users = FakeUserService();
      await openSheet(
        tester,
        platform: TargetPlatform.android,
        profile: FakeProfileService(),
        users: users,
      );

      await _register(tester, '010');
      expect(find.text('유효한 전화번호 형식이 아닙니다.'), findsOneWidget);
      expect(users.checkedPhones, isEmpty);
    });

    testWidgets('성별 정보가 없으면 시트에서 함께 받는다', (tester) async {
      final profile = FakeProfileService(gender: null);
      await openSheet(
        tester,
        platform: TargetPlatform.android,
        profile: profile,
        users: FakeUserService(),
      );

      await _register(tester, '010-1234-5678');
      expect(find.text('성별을 선택해 주세요.'), findsOneWidget);

      await tester.tap(find.text('여'));
      await tester.pump();
      await tester.tap(find.text('등록하기').last);
      await tester.pumpAndSettle();
      expect(profile.savedPhones, ['010-1234-5678']);
    });
  });
}
