import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';

import 'family_test_utils.dart';

FakeFamilyService _service() {
  final service = FakeFamilyService(
    groups: [fakeGroup(id: 1, name: '우리 가족'), fakeGroup(id: 2, name: '친구들')],
    members: [fakeMember(), fakeMember(userId: 2, name: '엄마', role: 'MEMBER')],
  );
  service.membersByGroup[2] = [fakeMember(userId: 3, name: '철수')];
  return service;
}

/// §6 W8 6항 — 가족 탭 재활성화 시 그룹/대시보드/초대를 다시 불러온다.
void main() {
  testWidgets('첫 방문에서는 중복 조회하지 않는다', (tester) async {
    final service = _service();
    await pumpFamilyShell(
      tester,
      familyService: service,
      profileService: FakeProfileService(phone: '010-1111-2222'),
      initialIndex: AppShellTab.home,
    );
    expect(service.getUserGroupsCalls, 0);

    tester.state<AppShellState>(find.byType(AppShell)).switchTab(AppShellTab.family);
    await tester.pumpAndSettle();

    expect(service.getUserGroupsCalls, 1);
    expect(service.getMyInvitationsCalls, 1);
  });

  testWidgets('다른 탭에 갔다가 돌아오면 그룹/초대를 다시 불러오고 새 초대가 보인다', (tester) async {
    final service = _service();
    await pumpFamilyShell(
      tester,
      familyService: service,
      profileService: FakeProfileService(phone: '010-1111-2222'),
    );
    expect(service.getUserGroupsCalls, 1);
    expect(find.text('그룹 초대가 왔어요!'), findsNothing);

    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.switchTab(AppShellTab.alarm);
    await tester.pumpAndSettle();
    service.invitations = [fakeInvitation()];
    shell.switchTab(AppShellTab.family);
    await tester.pumpAndSettle();

    expect(service.getUserGroupsCalls, 2);
    expect(service.getMyInvitationsCalls, 2);
    expect(find.text('그룹 초대가 왔어요!'), findsOneWidget);
  });

  testWidgets('재활성화 새로고침은 전체 로더 없이 기존 화면을 유지한다', (tester) async {
    final service = _service();
    await pumpFamilyShell(
      tester,
      familyService: service,
      profileService: FakeProfileService(phone: '010-1111-2222'),
    );
    final gate = Completer<void>();
    service.groupsGate = () => gate.future;

    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.switchTab(AppShellTab.alarm);
    await tester.pumpAndSettle();
    shell.switchTab(AppShellTab.family);
    await tester.pump();

    // 응답을 기다리는 동안에도 기존 멤버 목록이 그대로 보인다.
    expect(find.text('엄마'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('로드가 진행 중일 때 재활성화돼도 요청을 또 보내지 않는다', (tester) async {
    final service = _service();
    final gate = Completer<void>();
    service.groupsGate = () => gate.future;
    await pumpFamilyShell(
      tester,
      familyService: service,
      profileService: FakeProfileService(phone: '010-1111-2222'),
      initialIndex: AppShellTab.home,
    );
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.switchTab(AppShellTab.family);
    await tester.pump();
    expect(service.getUserGroupsCalls, 1);

    shell.switchTab(AppShellTab.family); // 같은 탭 재탭도 활성화 알림이다.
    await tester.pump();
    expect(service.getUserGroupsCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('낡은 응답은 무시한다: 새로고침 중 그룹을 바꾸면 이전 그룹 응답이 덮어쓰지 않는다', (tester) async {
    final service = _service();
    await pumpFamilyShell(
      tester,
      familyService: service,
      profileService: FakeProfileService(phone: '010-1111-2222'),
    );
    expect(find.text('엄마'), findsOneWidget);

    // 재활성화 새로고침이 그룹1 멤버 응답에서 멈춘다.
    final gate = Completer<void>();
    service.membersGates[1] = gate.future;
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.switchTab(AppShellTab.alarm);
    await tester.pumpAndSettle();
    shell.switchTab(AppShellTab.family);
    await tester.pump();
    await tester.pump();

    // 그 사이 사용자가 그룹2를 고른다.
    await tester.tap(find.text('우리 가족').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('친구들'));
    await tester.pumpAndSettle();
    expect(find.text('철수'), findsOneWidget);

    // 뒤늦게 도착한 그룹1 응답은 버려진다.
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('철수'), findsOneWidget);
    expect(find.text('엄마'), findsNothing);
  });

  testWidgets('재활성화 시 전화번호 등록 상태도 다시 확인한다(마이페이지에서 등록한 경우)', (tester) async {
    final profile = FakeProfileService();
    await pumpFamilyShell(
      tester,
      familyService: _service(),
      profileService: profile,
    );
    expect(find.text('가족이 나를 초대하려면 전화번호가 필요해요'), findsOneWidget);

    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.switchTab(AppShellTab.my);
    await tester.pumpAndSettle();
    profile.phone = '010-1234-5678';
    shell.switchTab(AppShellTab.family);
    await tester.pumpAndSettle();

    expect(find.text('가족이 나를 초대하려면 전화번호가 필요해요'), findsNothing);
  });
}
