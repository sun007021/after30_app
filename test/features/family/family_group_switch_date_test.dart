import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/ui/widgets/medication_record_sheet_content.dart';
import 'package:after30/features/family/ui/family_page.dart';

import 'family_test_utils.dart';

/// PR #35 재검토 R4: 그룹을 바꾼 직후 멤버 응답이 오기 전에 날짜를 누르면,
/// 날짜 선택이 선택 일련번호를 올려 그룹 로드가 기본 멤버 지정과 데이터 로드를
/// 통째로 건너뛰었다. 그룹 전환으로 선택된 멤버는 이미 비어 있으므로 시트가
/// 멤버 없이 빈 채로 남았다.
void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: 그룹 전환 직후(멤버 응답 전) 날짜를 눌러도 기본 멤버가 선택된다', (tester) async {
      useTallPhoneViewport(tester);
      final service = FakeFamilyService(
        groups: [fakeGroup(id: 1, name: '우리 가족'), fakeGroup(id: 2, name: '친구들')],
        members: [fakeMember(), fakeMember(userId: 2, name: '엄마', role: 'MEMBER')],
      );
      service.membersByGroup[2] = [fakeMember(userId: 3, name: '철수')];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build().copyWith(platform: platform),
        home: FamilyPage(
          familyService: service,
          profileService: FakeProfileService(phone: '010-1111-2222'),
          userService: FakeUserService(),
          fetchMemberMedications: noMedications,
        ),
      ));
      await tester.pumpAndSettle();

      // 그룹2의 멤버 응답을 붙잡아 둔 채 그룹을 바꾼다.
      final gate = Completer<void>();
      service.membersGates[2] = gate.future;
      await tester.tap(find.text('우리 가족').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('친구들').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 멤버 응답 전에 주간 스트립에서 오늘이 아닌 날짜를 누른다.
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday % 7));
      final other = List.generate(7, (i) => weekStart.add(Duration(days: i)))
          .firstWhere((d) => d.day != now.day);
      final dayFinder = find.descendant(
        of: find.byType(MedicationRecordSheetContent),
        matching: find.text('${other.day}'),
      );
      expect(dayFinder, findsWidgets, reason: '주간 스트립의 다른 날짜를 찾아야 재현된다');
      await tester.tap(dayFinder.first);
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('철수 복용 현황'), findsOneWidget);
    });
  }
}
