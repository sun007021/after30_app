import 'package:after30/core/network/api_client.dart';

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

  Future<dynamic> markTaken({
    required int scheduleId,
    required String scheduledDate,
    required String scheduledTime,
  }) async {
    return await processMedication(
      scheduleId: scheduleId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      action: 'taken',
    );
  }

  Future<dynamic> markMissed({
    required int scheduleId,
    required String scheduledDate,
    required String scheduledTime,
  }) async {
    return await processMedication(
      scheduleId: scheduleId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      action: 'missed',
    );
  }

  Future<dynamic> postpone({
    required int scheduleId,
    required String scheduledDate,
    required String scheduledTime,
    required String postponedTo, // HH:mm
  }) async {
    return await processMedication(
      scheduleId: scheduleId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      action: 'postponed',
      postponedTo: postponedTo,
    );
  }
}
