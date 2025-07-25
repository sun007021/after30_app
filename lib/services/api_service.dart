import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:after30/services/api_config.dart';

class ApiService {
  // 카카오 토큰을 백엔드로 전송하는 메서드
  static Future<Map<String, dynamic>> sendKakaoToken(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 사용자 정보를 백엔드로 전송하는 메서드
  static Future<Map<String, dynamic>> sendUserInfo(
    Map<String, dynamic> userInfo,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userInfo),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send user info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 백엔드 토큰을 저장하는 메서드
  static Future<void> saveBackendToken(String backendToken) async {
    // SharedPreferences나 다른 로컬 저장소를 사용하여 토큰 저장
    // 예시: await SharedPreferences.getInstance().then((prefs) => prefs.setString('backend_token', backendToken));
    print('Backend token saved: $backendToken');
  }
}
