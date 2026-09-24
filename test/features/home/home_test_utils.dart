import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';

/// 홈 화면 위젯 테스트에서 실제 네트워크 호출 없이 쓰는 가짜 가족
/// 서비스. `getHomeDashboard`/`getUserIdToGroupIdMap`만 오버라이드하고
/// 나머지는 [FamilyService]를 그대로 상속한다(다른 메서드는 테스트에서
/// 호출하지 않는다).
class FakeFamilyService extends FamilyService {
  FakeFamilyService({this.members = const []});

  final List<MemberMedicationSummary> members;

  @override
  Future<HomeDashboard> getHomeDashboard({DateTime? targetDate}) async {
    return HomeDashboard(date: DateTime.now(), membersSummary: members);
  }

  @override
  Future<Map<int, int>> getUserIdToGroupIdMap() async => const {};
}

/// 테스트용 [Medication] 픽스처.
Medication fakeMedication({
  required String time,
  required DateTime date,
  String status = 'pending',
  String name = '테스트 약',
  int scheduleId = 1,
  DateTime? takenAt,
}) {
  return Medication(
    id: '${scheduleId}_${date.toIso8601String()}_$time',
    name: name,
    dosage: '1정',
    time: time,
    date: date,
    status: status,
    scheduleId: scheduleId,
    takenAt: takenAt,
  );
}

/// 호출 횟수를 세는 가짜 복약 목록 조회 함수. 기본적으로 항상 [medications]를
/// 그대로 반환한다.
class CountingFetcher {
  CountingFetcher([List<Medication> Function()? provider]) : _provider = provider;

  final List<Medication> Function()? _provider;
  int callCount = 0;

  Future<List<Medication>> call(DateTime start, DateTime end) async {
    callCount++;
    return _provider?.call() ?? const [];
  }
}
