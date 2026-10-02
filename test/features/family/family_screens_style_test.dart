import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_select_page.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/features/family/ui/widgets/family_empty_state.dart';
import 'package:after30/features/family/ui/widgets/family_invitation_banner.dart';
import 'package:after30/features/family/ui/widgets/family_warn_icon.dart';

import 'family_test_utils.dart';

Future<void> _pumpWidget(WidgetTester tester, TargetPlatform platform, Widget home) async {
  useTallPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

class _GroupsService extends FakeFamilyService {
  @override
  Future<List<FamilyGroupDetail>> getUserGroupsWithMembers() async => [
        FamilyGroupDetail(
          group: fakeGroup(id: 1, name: '우리 가족'),
          members: [fakeMember(), fakeMember(userId: 2, name: '엄마', role: 'MEMBER')],
        ),
        FamilyGroupDetail(
          group: fakeGroup(id: 2, name: '친구들'),
          members: [fakeMember(userId: 3, name: '철수')],
        ),
      ];
}

/// §6 W8 5항 — 배너/빈 상태/경고 팝업/그룹 선택 화면은 iOS에서만 토큰 스타일.
void main() {
  group('그룹 선택 1단계', () {
    testWidgets('iOS: inset grouped 목록 + 셰브론', (tester) async {
      await _pumpWidget(tester, TargetPlatform.iOS, const FamilyInviteGroupSelectPage());
      expect(find.byType(AppGroupedSection), findsOneWidget);
      expect(find.byType(AppListTile), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNWidgets(2));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.groupedBackground);
    });

    testWidgets('Android: 기존 테두리 타일 그대로', (tester) async {
      await _pumpWidget(tester, TargetPlatform.android, const FamilyInviteGroupSelectPage());
      expect(find.byType(AppGroupedSection), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color.fromARGB(255, 255, 255, 255));
      final ink = tester.widget<Ink>(find.byType(Ink).first);
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.border, Border.all(color: const Color(0xFFA4A4A4)));
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });
  });

  group('기존 그룹 선택 2단계', () {
    testWidgets('iOS: inset grouped 목록, 체크 표시, 탭하면 초대 페이지로', (tester) async {
      await _pumpWidget(
        tester,
        TargetPlatform.iOS,
        FamilyInviteExistingGroupSelectPage(familyService: _GroupsService()),
      );
      expect(find.byType(AppGroupedSection), findsOneWidget);
      expect(find.byType(AppListTile), findsNWidgets(2));
      expect(find.byType(AppCheckmark), findsNWidgets(2));
      expect(
        tester.widgetList<AppCheckmark>(find.byType(AppCheckmark)).every((c) => !c.checked),
        isTrue,
      );
      expect(find.text('우리 가족'), findsOneWidget);

      await tester.tap(find.text('친구들'));
      await tester.pump();
      // 탭 직후 선택 체크가 켜진다.
      expect(tester.widgetList<AppCheckmark>(find.byType(AppCheckmark)).last.checked, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(FamilyInviteExistingGroupInvitePage), findsOneWidget);
    });

    testWidgets('Android: 기존 카드 목록 그대로', (tester) async {
      await _pumpWidget(
        tester,
        TargetPlatform.android,
        FamilyInviteExistingGroupSelectPage(familyService: _GroupsService()),
      );
      expect(find.byType(AppGroupedSection), findsNothing);
      expect(find.byType(AppCheckmark), findsNothing);
      final ink = tester.widgetList<Ink>(find.byType(Ink)).first;
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.border, Border.all(color: const Color(0xFF98C4FF)));
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });
  });

  group('빈 상태', () {
    testWidgets('iOS: 테두리 없는 카드 + AppButton', (tester) async {
      await _pumpWidget(tester, TargetPlatform.iOS, Scaffold(body: FamilyEmptyState(onCreateGroup: () {})));
      expect(find.byType(AppButton), findsOneWidget);
      final card = tester.widget<Container>(
        find.ancestor(of: find.text('등록된 가족이 없어요'), matching: find.byType(Container)).last,
      );
      expect(card.decoration, isA<ShapeDecoration>());
    });

    testWidgets('Android: 기존 테두리 카드와 파란 알약 버튼', (tester) async {
      await _pumpWidget(tester, TargetPlatform.android, Scaffold(body: FamilyEmptyState(onCreateGroup: () {})));
      expect(find.byType(AppButton), findsNothing);
      final card = tester.widgetList<Container>(
        find.ancestor(of: find.text('등록된 가족이 없어요'), matching: find.byType(Container)),
      ).firstWhere((c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).border != null);
      final box = card.decoration! as BoxDecoration;
      expect(box.border, Border.all(color: const Color(0xFFA4A4A4)));
      expect(box.color, Colors.white);
      final material = tester.widget<Material>(
        find.ancestor(of: find.text('새 그룹 생성하기'), matching: find.byType(Material)).first,
      );
      expect(material.color, const Color(0xFF235DFF));
      expect(material.borderRadius, BorderRadius.circular(30));
    });
  });

  group('초대 배너', () {
    testWidgets('iOS: 수락/거절이 AppButton', (tester) async {
      var accepted = 0;
      await _pumpWidget(
        tester,
        TargetPlatform.iOS,
        Scaffold(
          body: FamilyInvitationBanner(
            invitation: fakeInvitation(),
            onAccept: () => accepted++,
            onDecline: () {},
          ),
        ),
      );
      expect(find.byType(AppButton), findsNWidgets(2));
      await tester.tap(find.text('수락하기'));
      expect(accepted, 1);
    });

    testWidgets('Android: 기존 작은 텍스트 버튼과 흰 카드', (tester) async {
      await _pumpWidget(
        tester,
        TargetPlatform.android,
        Scaffold(
          body: FamilyInvitationBanner(
            invitation: fakeInvitation(),
            onAccept: () {},
            onDecline: () {},
          ),
        ),
      );
      expect(find.byType(AppButton), findsNothing);
      final accept = tester.widget<Material>(
        find.ancestor(of: find.text('수락하기'), matching: find.byType(Material)).first,
      );
      expect(accept.color, const Color(0xFF235DFF));
      expect(accept.borderRadius, BorderRadius.circular(6));
    });
  });

  group('전화번호 조회 불가 경고', () {
    Future<void> trigger(WidgetTester tester, TargetPlatform platform) async {
      await _pumpWidget(
        tester,
        platform,
        FamilyInviteExistingGroupInvitePage(
          groupId: 1,
          groupName: '우리 가족',
          familyService: FakeFamilyService(),
          profileService: FakeProfileService(phone: '010-1111-2222'),
          userService: FakeUserService(),
        ),
      );
      await tester.enterText(find.byType(EditableText).last, '01099998888');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      // 경고가 떠 있는 동안 조회 스피너가 계속 돌아 pumpAndSettle은 끝나지 않는다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('iOS: CupertinoAlertDialog', (tester) async {
      await trigger(tester, TargetPlatform.iOS);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('조회할 수 없습니다'), findsOneWidget);
      expect(find.byType(FamilyWarnIcon), findsNothing);
    });

    testWidgets('Android: 기존 커스텀 팝업', (tester) async {
      await trigger(tester, TargetPlatform.android);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(FamilyWarnIcon), findsOneWidget);
      expect(find.text('조회할 수 없습니다'), findsOneWidget);
    });
  });
}
