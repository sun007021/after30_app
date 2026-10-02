import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/models/family_group.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/features/my/models/user_by_phone_response.dart';

import '../../app/app_shell_test_utils.dart';

/// 실제 네트워크 없이 쓰는 가짜 가족 서비스. 호출 횟수/인자를 기록한다.
class FakeFamilyService extends FamilyService {
  FakeFamilyService({
    List<FamilyGroup>? groups,
    List<FamilyInvitation>? invitations,
    List<GroupMember>? members,
  })  : groups = groups ?? [],
        invitations = invitations ?? [],
        members = members ?? [];

  List<FamilyGroup> groups;
  List<FamilyInvitation> invitations;
  List<GroupMember> members;

  int getUserGroupsCalls = 0;
  int getMyInvitationsCalls = 0;
  final List<int> acceptedInvitationIds = [];
  final List<String> createdGroupNames = [];
  final List<String> sentPhones = [];
  final List<int> removedUserIds = [];
  final List<int> transferredToUserIds = [];
  final List<int> leftGroupIds = [];
  final List<String> renamedTo = [];

  /// 지정하면 [getUserGroups] 응답을 이 Completer가 풀릴 때까지 미룬다.
  Future<void> Function()? groupsGate;

  @override
  Future<List<FamilyGroup>> getUserGroups() async {
    getUserGroupsCalls++;
    final snapshot = List<FamilyGroup>.of(groups);
    await groupsGate?.call();
    return snapshot;
  }

  @override
  Future<List<FamilyInvitation>> getMyInvitations() async {
    getMyInvitationsCalls++;
    return List.of(invitations);
  }

  @override
  Future<List<GroupMember>> getGroupMembers(int groupId) async => List.of(members);

  @override
  Future<List<FamilyInvitation>> getGroupInvitations(int groupId) async => const [];

  @override
  Future<FamilyDashboard> getDashboard({required int groupId, DateTime? targetDate}) async {
    return FamilyDashboard(
      groupId: groupId,
      groupName: groups.isEmpty ? '' : groups.first.name,
      date: targetDate ?? DateTime.now(),
      membersSummary: [
        for (final m in members)
          MemberMedicationSummary(
            userId: m.userId,
            userName: m.userName,
            totalScheduled: 2,
            takenCount: 1,
            pendingCount: 1,
            missedCount: 0,
            complianceRate: 50,
          ),
      ],
    );
  }

  @override
  Future<void> acceptInvitation(int invitationId) async {
    acceptedInvitationIds.add(invitationId);
  }

  @override
  Future<void> declineInvitation(int invitationId) async {}

  @override
  Future<FamilyGroup> createGroup(String name) async {
    createdGroupNames.add(name);
    return fakeGroup(id: 99, name: name);
  }

  @override
  Future<void> sendInvitation({required int groupId, required String inviteePhoneNumber}) async {
    sentPhones.add(inviteePhoneNumber);
  }

  @override
  Future<void> removeMember({required int groupId, required int targetUserId}) async {
    removedUserIds.add(targetUserId);
  }

  @override
  Future<void> transferOwnership({required int groupId, required int newOwnerUserId}) async {
    transferredToUserIds.add(newOwnerUserId);
  }

  @override
  Future<void> leaveGroup(int groupId) async {
    leftGroupIds.add(groupId);
  }

  @override
  Future<FamilyGroup> updateGroupName({required int groupId, required String name}) async {
    renamedTo.add(name);
    return fakeGroup(id: groupId, name: name);
  }
}

/// 가짜 프로필 서비스. [phone]이 비어 있으면 미등록 사용자다.
class FakeProfileService extends MyProfileService {
  FakeProfileService({this.phone, this.gender = '남'});

  String? phone;
  String? gender;
  int getCalls = 0;
  final List<String> savedPhones = [];

  @override
  Future<MyProfile> getMyProfile() async {
    getCalls++;
    return MyProfile(name: '나', gender: gender, phoneNumber: phone);
  }

  @override
  Future<MyProfile> updateMyProfile({
    required String name,
    required String gender,
    required String phoneNumber,
  }) async {
    savedPhones.add(phoneNumber);
    phone = phoneNumber;
    return MyProfile(name: name, gender: gender, phoneNumber: phoneNumber);
  }
}

class FakeUserService extends UserService {
  FakeUserService({this.duplicatePhones = const {}, this.knownUsers = const {}});

  final Set<String> duplicatePhones;
  final Map<String, String> knownUsers;
  final List<String> checkedPhones = [];

  @override
  Future<bool> isPhoneDuplicate(String phoneNumber) async {
    checkedPhones.add(phoneNumber);
    return duplicatePhones.contains(phoneNumber);
  }

  @override
  Future<UserByPhoneResponse> getUserByPhone(String phoneNumber) async {
    final name = knownUsers[phoneNumber];
    return UserByPhoneResponse(exists: name != null, name: name);
  }
}

FamilyGroup fakeGroup({int id = 1, String name = '우리 가족', int owner = 1}) {
  final now = DateTime(2026, 1, 1);
  return FamilyGroup(
    id: id,
    name: name,
    createdByUserId: owner,
    memberCount: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

GroupMember fakeMember({int userId = 1, String name = '나', String role = 'OWNER'}) {
  return GroupMember(
    id: userId,
    groupId: 1,
    userId: userId,
    userName: name,
    role: role,
    joinedAt: DateTime(2026, 1, 1),
    isActive: true,
  );
}

FamilyInvitation fakeInvitation({int id = 5, String groupName = '엄마네'}) {
  return FamilyInvitation(
    id: id,
    groupId: 7,
    groupName: groupName,
    inviterUserId: 3,
    inviterName: '엄마',
    inviteePhoneNumber: '010-0000-0000',
    status: 'PENDING',
    expiresAt: DateTime(2099, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<List<Medication>> noMedications(int userId, DateTime day) async => const [];

/// 기본 테스트 화면(800x600)은 가족 탭 레이아웃에 비해 낮아 오버플로가 난다.
/// 실제 휴대폰 크기(390x844)로 맞춘다.
void useTallPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 지정한 [platform]으로 [FamilyPage]를 단독으로 펌프한다(셸 없음).
Future<void> pumpFamilyPage(
  WidgetTester tester, {
  required TargetPlatform platform,
  required FakeFamilyService familyService,
  required FakeProfileService profileService,
  FakeUserService? userService,
}) async {
  useTallPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: FamilyPage(
        familyService: familyService,
        profileService: profileService,
        userService: userService ?? FakeUserService(),
        fetchMemberMedications: noMedications,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 가족 탭에 실제 [FamilyPage]를 꽂은 [AppShell]을 펌프한다.
Future<void> pumpFamilyShell(
  WidgetTester tester, {
  required FakeFamilyService familyService,
  required FakeProfileService profileService,
  int initialIndex = AppShellTab.family,
}) async {
  useTallPhoneViewport(tester);
  final builders = testPageBuilders();
  builders[AppShellTab.family] = (context, args) => FamilyPage(
        familyService: familyService,
        profileService: profileService,
        userService: FakeUserService(),
        fetchMemberMedications: noMedications,
      );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: AppShell(initialIndex: initialIndex, pageBuilders: builders),
    ),
  );
  await tester.pumpAndSettle();
}
