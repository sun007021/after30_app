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

  /// 로그인 제공자를 화면에 보여줄 한국어 표시명으로 바꾼다(plan §6 W3a
  /// 6항). `my_info_edit_page.dart`(W9 소유)의 SSO 표시 행이 이 값을
  /// 쓴다.
  String get providerDisplayName => providerDisplayNameFor(provider);

  /// [provider] 문자열 하나만 있을 때도 같은 매핑을 쓸 수 있도록 정적으로도
  /// 노출한다(예: 탈퇴 다이얼로그가 프로필 전체를 만들지 않고도 분기할 때).
  static String providerDisplayNameFor(String? provider) {
    switch (provider?.trim().toLowerCase()) {
      case 'kakao':
        return '카카오톡';
      case 'email':
        return '이메일';
      case 'apple':
        // Apple 로그인은 W3b에서 추가된다(D14) — 표시명만 미리 준비해 둔다.
        return 'Apple';
      default:
        return '알 수 없음';
    }
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
