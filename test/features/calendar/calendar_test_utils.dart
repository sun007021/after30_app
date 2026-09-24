import 'package:after30/features/calendar/models/medication.dart';

/// 테스트용 [Medication] 픽스처.
Medication fakeMedication({
  required String time,
  required DateTime date,
  String status = 'pending',
  String name = '테스트 약',
  int scheduleId = 1,
}) {
  return Medication(
    id: '${scheduleId}_${date.toIso8601String()}_$time',
    name: name,
    dosage: '1정',
    time: time,
    date: date,
    status: status,
    scheduleId: scheduleId,
  );
}

/// 호출 횟수를 세는 가짜 복약 목록 조회 함수. 실제 네트워크 호출 없이
/// [medications]를 그대로 반환한다.
class CountingFetcher {
  CountingFetcher([List<Medication> Function()? provider]) : _provider = provider;

  final List<Medication> Function()? _provider;
  int callCount = 0;

  Future<List<Medication>> call(DateTime start, DateTime end) async {
    callCount++;
    return _provider?.call() ?? const [];
  }
}
