import 'package:after30/core/network/api_client.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/models/family_group.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:dio/dio.dart';

class FamilyGroupDetail {
  final FamilyGroup group;
  final List<GroupMember> members;

  FamilyGroupDetail({required this.group, required this.members});

  String get memberCountLabel {
    final count = group.memberCount ?? members.length;
    return '$count명';
  }

  String get memberNamesLabel {
    final names = members
        .map((member) => member.userName?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return '멤버 없음';
    return names.join(' ');
  }

  String get representativeLabel {
    final owner = members.where((member) => member.isOwner).firstOrNull;
    final name = owner?.userName?.trim();
    if (name == null || name.isEmpty) return '대표자: -';
    return '대표자:$name';
  }
}

class FamilyService {
  final Dio _client = ApiClient().dio;

  Future<List<FamilyGroup>> getUserGroups() async {
    final resp = await _client.get('/families/groups');
    final data = resp.data;
    if (data is! List) {
      throw Exception('Unexpected groups response');
    }
    return data
        .map((item) => FamilyGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    final resp = await _client.get('/families/groups/$groupId/members');
    final data = resp.data;
    if (data is! List) {
      throw Exception('Unexpected members response');
    }
    return data
        .map((item) => GroupMember.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<FamilyGroupDetail>> getUserGroupsWithMembers() async {
    final groups = await getUserGroups();
    final details = await Future.wait(
      groups.map((group) async {
        final members = await getGroupMembers(group.id);
        return FamilyGroupDetail(group: group, members: members);
      }),
    );
    return details;
  }

  Future<FamilyGroup> createGroup(String name) async {
    final resp = await _client.post(
      '/families/groups',
      data: {'name': name},
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return FamilyGroup.fromJson(data);
    }
    if (data is Map) {
      return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected create group response');
  }

  Future<void> sendInvitation({
    required int groupId,
    required String inviteePhoneNumber,
  }) async {
    await _client.post(
      '/families/invitations',
      data: {
        'group_id': groupId,
        'invitee_phone_number': inviteePhoneNumber,
      },
    );
  }

  Future<FamilyDashboard> getDashboard({
    required int groupId,
    DateTime? targetDate,
  }) async {
    final query = <String, dynamic>{};
    if (targetDate != null) {
      query['target_date'] = _formatDate(targetDate);
    }
    final resp = await _client.get(
      '/families/groups/$groupId/dashboard',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return FamilyDashboard.fromJson(data);
    }
    if (data is Map) {
      return FamilyDashboard.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected dashboard response');
  }

  /// 홈 가족 복약 대시보드 (`GET /families/dashboard`)
  /// 현재 사용자를 제외한 모든 그룹의 가족 멤버 복약 현황을 반환합니다.
  Future<HomeDashboard> getHomeDashboard({DateTime? targetDate}) async {
    final query = <String, dynamic>{};
    if (targetDate != null) {
      query['target_date'] = _formatDate(targetDate);
    }
    final resp = await _client.get(
      '/families/dashboard',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return HomeDashboard.fromJson(data);
    }
    if (data is Map) {
      return HomeDashboard.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected home dashboard response');
  }

  /// userId → 소속 groupId 매핑 (여러 그룹이면 첫 번째 그룹)
  Future<Map<int, int>> getUserIdToGroupIdMap() async {
    final details = await getUserGroupsWithMembers();
    final map = <int, int>{};
    for (final detail in details) {
      for (final member in detail.members) {
        map.putIfAbsent(member.userId, () => detail.group.id);
      }
    }
    return map;
  }

  Future<List<FamilyInvitation>> getMyInvitations() async {
    final resp = await _client.get('/families/invitations/my');
    final data = resp.data;
    if (data is! List) {
      throw Exception('Unexpected invitations response');
    }
    return data
        .map(
          (item) => FamilyInvitation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// 그룹에 보낸 초대 목록 (`GET /families/groups/{group_id}/invitations`)
  Future<List<FamilyInvitation>> getGroupInvitations(int groupId) async {
    final resp = await _client.get('/families/groups/$groupId/invitations');
    final data = resp.data;
    if (data is! List) {
      throw Exception('Unexpected group invitations response');
    }
    return data
        .map(
          (item) => FamilyInvitation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> acceptInvitation(int invitationId) async {
    await _client.post('/families/invitations/$invitationId/accept');
  }

  Future<void> declineInvitation(int invitationId) async {
    await _client.post('/families/invitations/$invitationId/decline');
  }

  Future<void> leaveGroup(int groupId) async {
    await _client.post('/families/groups/$groupId/leave');
  }

  Future<void> transferOwnership({
    required int groupId,
    required int newOwnerUserId,
  }) async {
    await _client.post(
      '/families/groups/$groupId/transfer-ownership',
      data: {'new_owner_user_id': newOwnerUserId},
    );
  }

  Future<void> removeMember({
    required int groupId,
    required int targetUserId,
  }) async {
    await _client.delete(
      '/families/groups/$groupId/members/$targetUserId',
    );
  }

  Future<FamilyGroup> updateGroupName({
    required int groupId,
    required String name,
  }) async {
    final resp = await _client.put(
      '/families/groups/$groupId',
      data: {'name': name},
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return FamilyGroup.fromJson(data);
    }
    if (data is Map) {
      return FamilyGroup.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected update group response');
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
