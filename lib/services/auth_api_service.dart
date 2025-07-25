import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:after30/services/api_config.dart';

class AuthApiService {
  // 카카오 Access Token으로 로그인(JWT 발급)
  static Future<Map<String, dynamic>> loginWithKakao(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.kakaoLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to login: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 만료된 Access Token을 Refresh Token으로 재발급
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tokenRefreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to refresh token: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 사용자 정보 전송(필요시)
  static Future<Map<String, dynamic>> sendUserInfo(
    Map<String, dynamic> userInfo,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.userProfileUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userInfo),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send user info: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<void> logout() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Logout failed: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
