class UserByPhoneResponse {
  final bool exists;
  final String? name;

  const UserByPhoneResponse({required this.exists, this.name});

  factory UserByPhoneResponse.fromJson(Map<String, dynamic> json) {
    final existsRaw = json['exists'];
    final exists = existsRaw == true ||
        existsRaw == 1 ||
        (existsRaw is String && existsRaw.toLowerCase() == 'true');
    final name = (json['name'] as String?)?.trim();
    final hasName = name != null && name.isNotEmpty;

    return UserByPhoneResponse(
      exists: exists || hasName,
      name: hasName ? name : null,
    );
  }
}
