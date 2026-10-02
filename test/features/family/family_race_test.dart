import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/features/family/ui/family_page.dart';

import '../../app/app_shell_test_utils.dart';

import 'family_test_utils.dart';

/// 리뷰(PR #35) 회귀 — 번호 확인(GET /users/me)이 네트워크 시간만큼 걸리는
/// 동안 진행 중 플래그가 없어 더블탭이 중복 동작을 일으키던 문제. 즉시
/// 응답하는 가짜로는 재현되지 않으므로 모든 테스트가 지연된 가짜를 쓴다.
void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('경쟁 상태 - $platform', () {
      testWidgets('B1 초대 하기 더블탭은 그룹을 한 번만 만들고 초대를 한 번만 보낸다', (tester) async {
        useTallPhoneViewport(tester);
        final family = FakeFamilyService()..createDelay = const Duration(milliseconds: 300);
        final profile = FakeProfileService(
          phone: '010-1111-2222',
          getDelay: const Duration(milliseconds: 400),
        );
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

        await tester.tap(find.text('초대 하기'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('초대 하기'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        expect(family.createdGroupNames, ['새 가족']);
        expect(family.sentPhones, ['+821099998888']);
        expect(profile.getCalls, 1);
      });

      testWidgets('M1 저장 중 배리어 탭으로는 시트가 닫히지 않고 저장 후 이어진다', (tester) async {
        useTallPhoneViewport(tester);
        final profile = FakeProfileService(saveDelay: const Duration(milliseconds: 600));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build().copyWith(platform: platform),
            home: FamilyPage(
              familyService: FakeFamilyService(),
              profileService: profile,
              userService: FakeUserService(),
              fetchMemberMedications: noMedications,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('새 그룹 생성하기'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, '01012345678');
        await tester.pump();
        await tester.tap(find.text('등록하기').last);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(const Offset(10, 10)); // 배리어 탭
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('전화번호를 등록해 주세요'), findsOneWidget, reason: '저장 중에는 닫히지 않는다');

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(profile.savedPhones, ['010-1234-5678']);
        expect(find.byType(FamilyInviteGroupSelectPage), findsOneWidget);
      });

      testWidgets('M1 시트가 닫히는 중 PATCH 응답이 와도 앱 셸이 pop되지 않고 등록은 성공으로 이어진다', (tester) async {
        useTallPhoneViewport(tester);
        final profile = FakeProfileService(saveDelay: const Duration(milliseconds: 300));
        final builders = testPageBuilders();
        builders[AppShellTab.family] = (context, args) => FamilyPage(
              familyService: FakeFamilyService(),
              profileService: profile,
              userService: FakeUserService(),
              fetchMemberMedications: noMedications,
            );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build().copyWith(platform: platform),
            home: AppShell(initialIndex: AppShellTab.family, pageBuilders: builders),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('새 그룹 생성하기'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, '01012345678');
        await tester.pump();
        await tester.tap(find.text('등록하기').last);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // 사용자가 시트를 쓸어내려 닫는다(저장 응답은 닫히는 애니메이션 중에 도착).
        Navigator.of(tester.element(find.byType(PhoneRegisterSheetContent))).pop();
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        expect(find.byType(AppShell), findsOneWidget, reason: '시트 대신 앱 셸이 pop됨');
        expect(find.byType(FamilyPage, skipOffstage: false), findsOneWidget);
        expect(profile.savedPhones, ['010-1234-5678']);
        // 서버에는 저장됐으므로 배너는 사라지고 원래 동작(그룹 생성 화면)이 이어진다.
        expect(find.text('가족이 나를 초대하려면 전화번호가 필요해요'), findsNothing);
        expect(find.byType(FamilyInviteGroupSelectPage), findsOneWidget);
      });

      testWidgets('번호 확인이 실패하면 다시 시도할 수 있게 풀린다', (tester) async {
        useTallPhoneViewport(tester);
        final family = FakeFamilyService();
        final profile = FakeProfileService(phone: '010-1111-2222')..failGet = true;
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

        await tester.tap(find.text('초대 하기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(family.createdGroupNames, isEmpty);

        profile.failGet = false;
        await tester.pump(const Duration(seconds: 6)); // 토스트 정리
        await tester.tap(find.text('초대 하기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(family.createdGroupNames, ['새 가족']);
      });
    });
  }
}
