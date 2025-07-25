class User {
  final int userId;
  final String name;

  User({required this.userId, required this.name});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(userId: json['user_id'], name: json['name'] ?? '');
  }
}

class LoginResponse {
  final String status;
  final String? message;
  final String? errorDetail;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final int? refreshExpiresIn;
  final bool isNewUser;
  final User? user;

  LoginResponse({
    required this.status,
    this.message,
    this.errorDetail,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.refreshExpiresIn,
    this.isNewUser = false,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    if (json['status'] == 'success') {
      final data = json['data'] ?? {};
      return LoginResponse(
        status: json['status'],
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        expiresIn: data['expires_in'],
        refreshExpiresIn: data['refresh_expires_in'],
        isNewUser: data['is_new_user'] ?? false,
        user: data['user'] != null ? User.fromJson(data['user']) : null,
      );
    } else {
      return LoginResponse(
        status: json['status'],
        message: json['message'],
        errorDetail: (json['errors']?['details'] as List?)?.join('\n'),
      );
    }
  }
}
