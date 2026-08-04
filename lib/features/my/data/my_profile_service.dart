import 'package:after30/core/network/api_client.dart';
import 'package:dio/dio.dart';

class MyProfile {
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? gender;
  final bool? allowMarketing;
  final String? profileImageUrl;
  final String? provider;

  MyProfile({
    this.name,
    this.email,
    this.phoneNumber,
    this.gender,
    this.allowMarketing,
    this.profileImageUrl,
    this.provider,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      name: (json['name'] as String?) ?? (json['nickname'] as String?),
      email: json['email'] as String?,
      phoneNumber:
          (json['phone_number'] as String?) ?? (json['phoneNumber'] as String?),
      gender: _parseGenderFromApi(json['gender'] as String?),
      allowMarketing:
          (json['allow_marketing'] as bool?) ??
          (json['allowMarketing'] as bool?),
      profileImageUrl:
          (json['profile_image_url'] as String?) ??
          (json['image_url'] as String?),
      provider: json['provider'] as String?,
    );
  }

  static String? _parseGenderFromApi(String? gender) {
    if (gender == null || gender.trim().isEmpty) return null;
    switch (gender.trim().toUpperCase()) {
      case 'MALE':
      case '남':
        return '남';
      case 'FEMALE':
      case '여':
        return '여';
      case 'OTHER':
        return '기타';
      default:
        return gender;
    }
  }

  static String genderToApi(String gender) {
    switch (gender.trim()) {
      case '남':
        return 'MALE';
      case '여':
        return 'FEMALE';
      case 'MALE':
      case 'FEMALE':
      case 'OTHER':
        return gender.trim().toUpperCase();
      default:
        return gender;
    }
  }

  bool get hasPhoneNumber {
    final phone = phoneNumber?.trim();
    return phone != null && phone.isNotEmpty;
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

  Future<MyProfile> updateMyProfile({
    required String name,
    required String gender,
    required String phoneNumber,
  }) async {
    final resp = await _client.patch(
      '/users/me',
      data: {
        'name': name,
        'gender': MyProfile.genderToApi(gender),
        'phone_number': phoneNumber,
      },
    );
    final responseData = resp.data;
    if (responseData is Map<String, dynamic>) {
      return MyProfile.fromJson(responseData);
    }
    if (responseData is Map) {
      return MyProfile.fromJson(Map<String, dynamic>.from(responseData));
    }
    return getMyProfile();
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
