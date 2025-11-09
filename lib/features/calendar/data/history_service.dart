import 'package:after30/core/network/api_client.dart';

class HistoryService {
  final _client = ApiClient().dio;

  // 기간 이력 조회: 일자별 상세를 평탄화하여 개별 히스토리 리스트로 반환
  Future<List<dynamic>> getUserHistories({
    required String startDate, // YYYY-MM-DD
    required String endDate, // YYYY-MM-DD
  }) async {
    final resp = await _client.get(
      '/histories/',
      queryParameters: {'start_date': startDate, 'end_date': endDate},
    );
    final data = resp.data as Map<String, dynamic>;
    final daily = (data['daily_details'] as List?) ?? const [];
    final flat = <dynamic>[];
    for (final d in daily) {
      if (d is! Map<String, dynamic>) continue;
      final histories = (d['histories'] as List?) ?? const [];
      for (final h in histories) {
        flat.add(h);
      }
    }
    return flat;
  }

  // 복용 완료 처리
  Future<dynamic> markTaken({
    required int scheduleId,
    required String scheduledDate, // YYYY-MM-DD
    required String scheduledTime, // HH:mm or HH:mm:ss
  }) async {
    final resp = await _client.post(
      '/histories/process',
      data: {
        'schedule_id': scheduleId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'action': 'taken',
      },
    );
    return resp.data;
  }
}
