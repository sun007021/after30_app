class FamilyInvitation {
  final int id;
  final int groupId;
  final String? groupName;
  final int inviterUserId;
  final String? inviterName;
  final String inviteePhoneNumber;
  final int? inviteeUserId;
  final String? inviteeName;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  FamilyInvitation({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.inviterUserId,
    this.inviterName,
    required this.inviteePhoneNumber,
    this.inviteeUserId,
    this.inviteeName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    return FamilyInvitation(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      groupName: json['group_name'] as String?,
      inviterUserId: json['inviter_user_id'] as int,
      inviterName: json['inviter_name'] as String?,
      inviteePhoneNumber: json['invitee_phone_number'] as String,
      inviteeUserId: json['invitee_user_id'] as int?,
      inviteeName: json['invitee_name'] as String?,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPending => status.toUpperCase() == 'PENDING';

  /// 멤버 행에 표시할 이름 (초대 대상 이름 → 없으면 전화번호 끝자리)
  String get displayName {
    final name = inviteeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final phone = inviteePhoneNumber.trim();
    if (phone.length >= 4) return phone.substring(phone.length - 4);
    return phone.isEmpty ? '초대중' : phone;
  }
}
