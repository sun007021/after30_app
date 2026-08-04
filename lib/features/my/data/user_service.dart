import 'package:after30/core/network/api_client.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/my/models/user_by_phone_response.dart';
import 'package:dio/dio.dart';

class UserService {
  final Dio _client = ApiClient().dio;

  Future<UserByPhoneResponse> getUserByPhone(String phoneNumber) async {
    final queryPhone = PhoneUtil.toApiPhoneQuery(phoneNumber);
    final resp = await _client.get(
      '/users/by-phone',
      queryParameters: {'phone_number': queryPhone},
    );
    final data = resp.data;
    // ignore: avoid_print
    print('📞 by-phone request=$queryPhone response=$data');
    if (data is Map<String, dynamic>) {
      return UserByPhoneResponse.fromJson(data);
    }
    if (data is Map) {
      return UserByPhoneResponse.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Unexpected user by phone response');
  }

  /// GET /users/check-phone — 전화번호 중복 여부 확인
  Future<bool> isPhoneDuplicate(String phoneNumber) async {
    final queryPhone = PhoneUtil.toApiPhoneQuery(phoneNumber);
    final resp = await _client.get(
      '/users/check-phone',
      queryParameters: {'phone_number': queryPhone},
      options: Options(extra: {'skipAuth': true}),
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return data['is_duplicate'] as bool? ?? false;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data)['is_duplicate'] as bool? ?? false;
    }
    throw Exception('Unexpected phone duplicate check response');
  }
}
