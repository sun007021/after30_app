import 'package:after30/core/network/api_client.dart';

class ScheduleService {
  final _client = ApiClient().dio;

  Future<dynamic> createSchedule(Map<String, dynamic> body) async {
    final resp = await _client.post('/schedules/', data: body);
    return resp.data;
  }

  Future<List<dynamic>> getSchedules({
    bool includeInactive = false,
    int? userId,
  }) async {
    final query = <String, dynamic>{'include_inactive': includeInactive};
    if (userId != null) {
      query['user_id'] = userId;
    }
    final resp = await _client.get(
      '/schedules/',
      queryParameters: query,
    );
    return (resp.data as List).cast<dynamic>();
  }

  Future<dynamic> getSchedule(int scheduleId) async {
    final resp = await _client.get('/schedules/$scheduleId');
    return resp.data;
  }

  Future<dynamic> updateSchedule(
    int scheduleId,
    Map<String, dynamic> body,
  ) async {
    final resp = await _client.put('/schedules/$scheduleId', data: body);
    return resp.data;
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _client.delete('/schedules/$scheduleId');
  }

  Future<dynamic> deactivateSchedule(int scheduleId) async {
    final resp = await _client.patch('/schedules/$scheduleId/deactivate');
    return resp.data;
  }

  Future<dynamic> activateSchedule(int scheduleId) async {
    final resp = await _client.patch('/schedules/$scheduleId/activate');
    return resp.data;
  }
}
