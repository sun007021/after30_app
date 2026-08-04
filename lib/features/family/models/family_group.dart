class FamilyGroup {
  final int id;
  final String name;
  final int createdByUserId;
  final int? memberCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyGroup({
    required this.id,
    required this.name,
    required this.createdByUserId,
    this.memberCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyGroup.fromJson(Map<String, dynamic> json) {
    return FamilyGroup(
      id: json['id'] as int,
      name: json['name'] as String,
      createdByUserId: json['created_by_user_id'] as int,
      memberCount: json['member_count'] as int?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
