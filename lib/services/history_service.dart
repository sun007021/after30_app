import 'package:after30/services/api_client.dart';

class HistoryService {
  final _client = ApiClient().dio;

  Future<dynamic> getUserHistories({String? startDate, String? endDate}) async {
    final resp = await _client.get(
      '/histories/',
      queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return resp.data;
  }

  Future<dynamic> getHistory(int historyId) async {
    final resp = await _client.get('/histories/$historyId');
    return resp.data;
  }

  Future<void> deleteHistory(int historyId) async {
    await _client.delete('/histories/$historyId');
  }

  Future<dynamic> processMedication({
    required int scheduleId,
    required String scheduledDate,
    required String scheduledTime,
    required String action,
    String? postponedTo,
  }) async {
    final resp = await _client.post(
      '/histories/process',
      data: {
        'schedule_id': scheduleId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'action': action,
        'postponed_to': postponedTo,
      },
    );
    return resp.data;
  }
}



