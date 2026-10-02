import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// 알람을 실제 기기에 등록/취소하는 전략의 공통 인터페이스(plan §6 W4 1항).
///
/// 구현체:
/// - [AwesomeReminderScheduler]: Android 전 버전, iOS 16~25(및 AlarmKit 권한이
///   없는 iOS 26+)에서 쓰는 awesome_notifications 기반 구현.
/// - `AlarmKitReminderScheduler`(iOS 전용): iOS 26+ AlarmKit 브리지.
///
/// `AlarmService`는 이 인터페이스 뒤에서 두 구현을 감싸는 선택기를 들고
/// 있고, 호출부(화면 등)는 여전히 `AlarmService`의 공개 API만 사용한다.
abstract class ReminderScheduler {
  /// 알람 하나를 기기에 등록(수정 시 기존 예약을 대체)한다. 성공 여부를 반환한다.
  Future<bool> schedule(MedicineAlarm alarm);

  /// 알람 하나의 기기 예약만 취소한다(저장된 알람 데이터는 건드리지 않음).
  Future<void> cancel(String alarmId);

  /// 이 스케줄러가 등록한 모든 예약/알림을 취소한다.
  Future<void> cancelAll();

  /// 저장소의 활성 알람 목록을 기준으로 전체를 다시 계산해 등록한다.
  /// iOS 로컬 알림 구현은 이 메서드를 앱 포그라운드 진입 시 호출해
  /// 64개 예산 창을 앞으로 굴린다(plan §7 리스크).
  Future<void> rescheduleAll(List<MedicineAlarm> activeAlarms);

  /// 현재 대기 중인 예약 수와 한도. 안드로이드/AlarmKit처럼 실질적으로
  /// 한도가 없는 구현은 [ReminderBudgetStatus.unlimited]를 반환한다.
  Future<ReminderBudgetStatus> pendingBudget();
}

/// 대기 중(pending) 알림 예산 상태. iOS 로컬 알림은 앱당 64건 제한이 있다
/// (plan §1.3, §7).
class ReminderBudgetStatus {
  const ReminderBudgetStatus({required this.used, required this.capacity});

  /// 무제한(Android, AlarmKit)을 표현하는 상수.
  static const ReminderBudgetStatus unlimited = ReminderBudgetStatus(
    used: 0,
    capacity: -1,
  );

  final int used;

  /// -1이면 무제한을 뜻한다.
  final int capacity;

  bool get isLimited => capacity >= 0;

  bool get isOverCapacity => isLimited && used > capacity;

  int get remaining => isLimited ? (capacity - used).clamp(0, capacity) : used;
}
