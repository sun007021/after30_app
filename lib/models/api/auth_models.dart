class KakaoLoginResponse {
  final String accessToken;
  final String refreshToken;
  final int accessExpiresIn;
  final int refreshExpiresIn;
  final bool isNewUser;

  KakaoLoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresIn,
    required this.refreshExpiresIn,
    required this.isNewUser,
  });

  factory KakaoLoginResponse.fromJson(Map<String, dynamic> json) {
    return KakaoLoginResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessExpiresIn: (json['access_expires_in'] as num).toInt(),
      refreshExpiresIn: (json['refresh_expires_in'] as num).toInt(),
      isNewUser: json['is_new_user'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_in': accessExpiresIn,
    'refresh_expires_in': refreshExpiresIn,
    'is_new_user': isNewUser,
  };
}

class RefreshTokenRequest {
  final String refreshToken;
  RefreshTokenRequest({required this.refreshToken});
  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

class RefreshTokenResponse {
  final String accessToken;
  final int accessExpiresIn;
  RefreshTokenResponse({
    required this.accessToken,
    required this.accessExpiresIn,
  });
  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      RefreshTokenResponse(
        accessToken: json['access_token'] as String,
        accessExpiresIn: (json['access_expires_in'] as num).toInt(),
      );
}



