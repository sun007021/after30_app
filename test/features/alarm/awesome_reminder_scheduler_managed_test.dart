import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 리뷰 M10 회귀 테스트: iOS 로컬 알림이 64개 예산 초과로 알림 id가
  // 없어도([]) "현재 전략이 이미 관리 중"이라는 기록(`isManagedByCurrentIosPass`)이
  // 있으면 `AlarmService.hasScheduledNotifications`가 새 기기/재설치
  // 복구 대상으로 착각하지 않는다. `_rescheduleIos`는 Platform.isIOS
  // 분기 안이라 이 테스트 환경(host=macOS)에서 직접 태울 수 없어, 그
  // 재계산이 남기는 저장소 기록(`reminder_ios_managed_alarm_ids`)을
  // 직접 시딩해 조회 로직만 검증한다.
  test('예산 재계산에서 관리 중으로 기록된 알람 id는 true를 반환한다', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_ios_managed_alarm_ids': ['a1', 'a2'],
    });
    final scheduler = AwesomeReminderScheduler(
      notificationIdsKeyFor: (id) => 'notification_ids_$id',
      deviceNotificationsAllowed: () async => true,
    );

    expect(await scheduler.isManagedByCurrentIosPass('a1'), isTrue);
    expect(await scheduler.isManagedByCurrentIosPass('a2'), isTrue);
    expect(await scheduler.isManagedByCurrentIosPass('없는알람'), isFalse);
  });

  test('기록이 없으면(한 번도 재계산되지 않음) false를 반환한다', () async {
    SharedPreferences.setMockInitialValues({});
    final scheduler = AwesomeReminderScheduler(
      notificationIdsKeyFor: (id) => 'notification_ids_$id',
      deviceNotificationsAllowed: () async => true,
    );

    expect(await scheduler.isManagedByCurrentIosPass('a1'), isFalse);
  });
}
