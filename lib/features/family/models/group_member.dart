class GroupMember {
  final int id;
  final int groupId;
  final int userId;
  final String? userName;
  final String? userPhoneNumber;
  final String role;
  final DateTime joinedAt;
  final bool isActive;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.userName,
    this.userPhoneNumber,
    required this.role,
    required this.joinedAt,
    required this.isActive,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String?,
      userPhoneNumber: json['user_phone_number'] as String?,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isActive: json['is_active'] as bool,
    );
  }

  bool get isOwner => role.toUpperCase() == 'OWNER';
}
