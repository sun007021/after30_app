import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/core/network/api_client.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';

/// `/schedules/` GET과 `/histories/process` POST만 응답하는 가짜
/// `HttpClientAdapter`. dio는 `ApiClient` 싱글톤 안에 이미 생성돼 있으므로,
/// 새 패키지를 추가하지 않고 `httpClientAdapter`만 이 페이크로 바꿔
/// `AlarmService.markTakenFromUi`(구 `_markTakenBestEffort`)의 매칭 로직을
/// 회귀 검증한다(plan §6 W4 8항).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.schedules});

  final List<Map<String, dynamic>> schedules;
  final List<RequestOptions> processCalls = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/schedules/' && options.method == 'GET') {
      return ResponseBody.fromString(
        json.encode(schedules),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/histories/process' && options.method == 'POST') {
      processCalls.add(options);
      return ResponseBody.fromString(
        json.encode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('not found', 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _FakeAdapter(
      schedules: [
        {
          'id': 101,
          'medication_name': '혈압약',
          'times': ['08:00'],
          'repeat_days': ['MON', 'WED', 'FRI'],
        },
        {
          'id': 202,
          'medication_name': '영양제',
          'times': ['09:00', '21:00'],
          'repeat_days': <String>[], // 빈 배열 = 매일
        },
      ],
    );
    ApiClient().dio.httpClientAdapter = adapter;
  });

  test('요일·시간이 정확히 일치하면 매칭된 scheduleId로 복용 완료 처리된다', () async {
    final success = await AlarmService.markTakenFromUi(
      medicineName: '혈압약',
      dayKor: '월',
      hhmm: '08:00',
    );
    expect(success, isTrue);
    expect(adapter.processCalls, hasLength(1));
    final body = adapter.processCalls.single.data as Map;
    expect(body['schedule_id'], 101);
    expect(body['scheduled_time'], '08:00');
  });

  test('매일 반복(repeat_days 빈 배열)인 스케줄은 어떤 요일과도 매칭된다', () async {
    final success = await AlarmService.markTakenFromUi(
      medicineName: '영양제',
      dayKor: '일',
      hhmm: '21:00',
    );
    expect(success, isTrue);
    expect(adapter.processCalls.single.data['schedule_id'], 202);
  });

  test('시:분:초(HH:mm:ss) 표기도 HH:mm으로 정규화해 매칭한다', () async {
    final success = await AlarmService.markTakenFromUi(
      medicineName: '혈압약',
      dayKor: '수',
      hhmm: '08:00:00',
    );
    expect(success, isTrue);
  });

  test('요일이 스케줄에 없으면 매칭 실패(false)로 처리하고 API를 호출하지 않는다', () async {
    final success = await AlarmService.markTakenFromUi(
      medicineName: '혈압약',
      dayKor: '화', // 혈압약은 월/수/금만 해당
      hhmm: '08:00',
    );
    expect(success, isFalse);
    expect(adapter.processCalls, isEmpty);
  });

  test('약 이름이 다르면 매칭 실패로 처리한다', () async {
    final success = await AlarmService.markTakenFromUi(
      medicineName: '없는약',
      dayKor: '월',
      hhmm: '08:00',
    );
    expect(success, isFalse);
    expect(adapter.processCalls, isEmpty);
  });
}
