import 'package:after30/core/network/api_client.dart';
import 'package:dio/dio.dart';

class MyProfile {
  final String? name;
  final String? email;
  final bool? allowMarketing;
  final String? profileImageUrl;

  MyProfile({this.name, this.email, this.allowMarketing, this.profileImageUrl});

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      name: (json['name'] as String?) ?? (json['nickname'] as String?),
      email: json['email'] as String?,
      allowMarketing:
          (json['allow_marketing'] as bool?) ??
          (json['allowMarketing'] as bool?),
      profileImageUrl:
          (json['profile_image_url'] as String?) ??
          (json['image_url'] as String?),
    );
  }
}

class MyProfileService {
  final Dio _client = ApiClient().dio;

  Future<MyProfile> getMyProfile() async {
    final resp = await _client.get('/users/me');
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return MyProfile.fromJson(data);
    }
    if (data is Map) {
      return MyProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected profile response');
  }

  Future<void> updateFcmToken(String token) async {
    await _client.patch('/users/me/fcm-token', data: {'fcm_token': token});
  }

  /// 이메일 로그인 사용자의 계정 삭제
  Future<void> deleteAccountWithPassword(String password) async {
    await _client.delete(
      '/users/account',
      data: {'password': password},
      options: Options(extra: {'noRefresh': true}),
    );
  }

  /// 카카오 로그인 사용자의 계정 삭제 (재인증 토큰 필요)
  Future<void> deleteAccountWithKakao(String kakaoAccessToken) async {
    await _client.delete(
      '/users/account',
      data: {'kakao_access_token': kakaoAccessToken},
      options: Options(extra: {'noRefresh': true}),
    );
  }
}
