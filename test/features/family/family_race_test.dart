import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';

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
