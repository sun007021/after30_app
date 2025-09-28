class FamilyMember {
  final String id;
  final String name;
  final String phone;
  final DateTime joinedAt;
  final String? profileImageUrl;

  FamilyMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.joinedAt,
    this.profileImageUrl,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      joinedAt: DateTime.parse(json['joinedAt']),
      profileImageUrl: json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'joinedAt': joinedAt.toIso8601String(),
      'profileImageUrl': profileImageUrl,
    };
  }
}

