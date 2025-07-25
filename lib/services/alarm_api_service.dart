import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:after30/services/api_config.dart';

class AlarmApiService {
  // 알람 목록 조회
  static Future<List<Map<String, dynamic>>> getAlarmList() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/alarms'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get alarms: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 알람 생성
  static Future<Map<String, dynamic>> createAlarm(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/alarms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(alarmData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create alarm: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 알람 수정
  static Future<Map<String, dynamic>> updateAlarm(
    String alarmId,
    Map<String, dynamic> alarmData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/alarms/$alarmId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(alarmData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update alarm: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 알람 삭제
  static Future<void> deleteAlarm(String alarmId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/alarms/$alarmId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete alarm: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
