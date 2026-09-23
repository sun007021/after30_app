import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// iOS 로컬 알림의 64개 대기(pending request) 예산을 계산하는 순수 로직
/// (plan §1.3, §6 W4 2항, §7 리스크). awesome_notifications/플랫폼 채널을
/// 전혀 쓰지 않으므로 단위 테스트로 검증한다.
class ReminderBudgetPlanner {
  ReminderBudgetPlanner._();

  /// iOS가 앱당 허용하는 대기 중 로컬 알림 한도.
  static const int iosPendingLimit = 64;

  /// 알람 하나가 iOS에서 필요로 하는 "반복" 요청 수.
  ///
  /// 7일 모두 선택된 경우 요일 없는 매일 반복 1건으로 합치므로(요청당
  /// 시간 하나) `times.length`만 소비한다. 일부 요일만 선택된 경우
  /// 기존 Android 방식과 동일하게 요일×시간 조합마다 1건이 필요하다.
  /// 비활성 알람은 0건이다.
  static int requestCost(MedicineAlarm alarm) {
    if (!alarm.isActive) return 0;
    if (alarm.times.isEmpty || alarm.days.isEmpty) return 0;
    final distinctDays = alarm.days.toSet().length;
    final dayMultiplier = distinctDays >= 7 ? 1 : distinctDays;
    return alarm.times.length * dayMultiplier;
  }

  /// 여러 알람 전체가 필요로 하는 반복 요청 수 합계.
  static int totalRequestCost(List<MedicineAlarm> alarms) {
    var sum = 0;
    for (final alarm in alarms) {
      sum += requestCost(alarm);
    }
    return sum;
  }

  /// 예산 초과 여부(현재 요청 합계 기준).
  static bool exceedsBudget(List<MedicineAlarm> alarms) {
    return totalRequestCost(alarms) > iosPendingLimit;
  }
}

/// 알람의 요일 하나 + 시간 하나에 대한 다음 발생 시각 하나를 표현한다.
/// 64개 예산을 초과했을 때 "가장 가까운 발생분부터" 골라 담는 롤링
/// 스케줄링에 쓰인다(plan §6 W4 2항).
class ReminderOccurrence implements Comparable<ReminderOccurrence> {
  const ReminderOccurrence({
    required this.alarmId,
    required this.medicineName,
    required this.dayKor,
    required this.hour,
    required this.minute,
    required this.nextFireAt,
  });

  final String alarmId;
  final String medicineName;
  final String dayKor;
  final int hour;
  final int minute;
  final DateTime nextFireAt;

  @override
  int compareTo(ReminderOccurrence other) => nextFireAt.compareTo(other.nextFireAt);
}

/// 요일(월~일) → ISO 8601 weekday(1=월 ... 7=일) 매핑. `awesome_reminder_scheduler`
/// 및 롤링 재예약 계산에서 함께 쓴다.
const Map<String, int> kKoreanDayToIsoWeekday = {
  '월': 1,
  '화': 2,
  '수': 3,
  '목': 4,
  '금': 5,
  '토': 6,
  '일': 7,
};

/// [ReminderBudgetPlanner]와 함께 쓰는 발생 시각 계산기. `now` 이후 해당
/// 요일·시간의 가장 가까운 발생 시각을 구한다(오늘 그 시간이 이미 지났으면
/// 다음 주).
DateTime nextOccurrenceOf({
  required DateTime now,
  required String dayKor,
  required int hour,
  required int minute,
}) {
  final targetWeekday = kKoreanDayToIsoWeekday[dayKor] ?? DateTime.monday;
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  final todayWeekday = now.weekday;
  var dayDelta = targetWeekday - todayWeekday;
  if (dayDelta < 0) dayDelta += 7;
  candidate = candidate.add(Duration(days: dayDelta));
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}

/// 활성 알람 전체에서 "요일×시간" 발생 목록을 만들고, 예산을 초과하면
/// 가장 가까운 [ReminderBudgetPlanner.iosPendingLimit]개만 남긴다.
/// 7일 알람은 요일 구분 없이 "매일" 한 건으로 취급해 발생 시각만 계산한다
/// (실제 등록은 daily-repeat 1건으로 하되, 예산 계산에서는 요청 비용이
/// 1이라는 점과 일치시키기 위해 대표 요일 하나만 담는다).
List<ReminderOccurrence> buildBudgetedOccurrences({
  required List<MedicineAlarm> activeAlarms,
  required DateTime now,
  int limit = ReminderBudgetPlanner.iosPendingLimit,
}) {
  final occurrences = <ReminderOccurrence>[];
  for (final alarm in activeAlarms) {
    if (!alarm.isActive || alarm.times.isEmpty || alarm.days.isEmpty) continue;
    final distinctDays = alarm.days.toSet().length;
    final isDaily = distinctDays >= 7;
    final days = isDaily ? [alarm.days.first] : alarm.days.toSet().toList();
    for (final day in days) {
      for (final time in alarm.times) {
        occurrences.add(
          ReminderOccurrence(
            alarmId: alarm.id,
            medicineName: alarm.name,
            dayKor: day,
            hour: time.hour,
            minute: time.minute,
            nextFireAt: nextOccurrenceOf(
              now: now,
              dayKor: day,
              hour: time.hour,
              minute: time.minute,
            ),
          ),
        );
      }
    }
  }
  occurrences.sort();
  if (occurrences.length <= limit) return occurrences;
  return occurrences.sublist(0, limit);
}
