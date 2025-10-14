import 'package:after30/core/network/api_client.dart';
import 'package:dio/dio.dart';

class HistoryService {
  final _client = ApiClient().dio;

  Future<List<dynamic>> getUserHistories({
    String? startDate,
    String? endDate,
  }) async {
    final resp = await _client.get(
      '/histories/',
      queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    // ignore: avoid_print
    print('📘 GET /histories → ${resp.statusCode} ${resp.data.runtimeType}');
    final data = resp.data;
    if (data is List) {
      return data.cast<dynamic>();
    }
    if (data is Map<String, dynamic>) {
      final list =
          data['items'] ??
          data['data'] ??
          data['results'] ??
          data['histories'] ??
          [];
      if (list is List) return list.cast<dynamic>();
    }
    return const <dynamic>[];
  }

  Future<dynamic> getHistory(int historyId) async {
    final resp = await _client.get('/histories/$historyId');
    // ignore: avoid_print
    print('📘 GET /histories/$historyId → ${resp.statusCode}');
    return resp.data;
  }

  Future<dynamic> updateHistory(
    int historyId,
    Map<String, dynamic> body,
  ) async {
    // status가 문자열이면 서버 enum에 맞게 소문자로 변환
    if (body.containsKey('status') && body['status'] is String) {
      body = {...body, 'status': (body['status'] as String).toLowerCase()};
    }
    try {
      final resp = await _client.put('/histories/$historyId', data: body);
      // ignore: avoid_print
      print('🟡 PUT /histories/$historyId → ${resp.statusCode} ${resp.data}');
      return resp.data;
    } on DioException catch (e) {
      // ignore: avoid_print
      print(
        '❌ PUT /histories/$historyId ${e.response?.statusCode} ${e.response?.data}',
      );
      rethrow;
    }
  }

  Future<dynamic> processMedication({
    required int scheduleId,
    required String scheduledDate,
    required String scheduledTime,
    required String action,
    String? postponedTo,
  }) async {
    String _fmtDate(String s) {
      try {
        final d = DateTime.parse(s);
        return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return s;
      }
    }

    // 서버는 HH:mm 형식만 허용
    String _fmtTime(String s) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(s);
      if (m != null) {
        final hh = (m.group(1) ?? '0').padLeft(2, '0');
        final mm = m.group(2) ?? '00';
        return '$hh:$mm';
      }
      if (RegExp(r'^\d{3,4}$').hasMatch(s)) {
        final p = s.padLeft(4, '0');
        return '${p.substring(0, 2)}:${p.substring(2, 4)}';
      }
      return s;
    }

    final body = {
      'schedule_id': scheduleId,
      'scheduled_date': _fmtDate(scheduledDate),
      'scheduled_time': _fmtTime(scheduledTime),
      'action': action.toLowerCase(),
      if (postponedTo != null) 'postponed_to': _fmtTime(postponedTo),
    };
    try {
      final resp = await _client.post('/histories/process', data: body);
      // ignore: avoid_print
      print(
        '🟢 POST /histories/process(${body['action']}) → ${resp.statusCode} ${resp.data}',
      );
      return resp.data;
    } on DioException catch (e) {
      // ignore: avoid_print
      print(
        '❌ POST /histories/process ${e.response?.statusCode} ${e.response?.data}',
      );
      // 이미 taken 처리된 경우는 멱등 성공으로 간주
      final data = e.response?.data;
      final msg = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : '';
      if (e.response?.statusCode == 400 && msg.contains('이미 taken 상태')) {
        // ignore: avoid_print
        print('ℹ️ processMedication: already taken → treat as success');
        return {'status': 'taken'};
      }
      rethrow;
    }
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
