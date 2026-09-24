import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler_selector.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// `ReminderSchedulerSelector`의 "전략 선택"과 "전략 전환 시 이전 전략
/// 취소"를 검증한다. 알람의 요일/시간을 비워 두면
/// `AwesomeReminderScheduler`가 실제 알림을 하나도 만들지 않으므로
/// (`createNewNotification` 채널 호출이 발생하지 않으므로), 복잡한
/// awesome_notifications 콘텐츠 직렬화를 목(mock)하지 않고도 실제
/// 스케줄러 인스턴스로 이 로직만 분리해 검증할 수 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const alarmKitChannel = MethodChannel('after30/alarmkit');
  const awesomeChannel = MethodChannel('awesome_notifications');
  final awesomeCalls = <String>[];

  Future<void> setAlarmKitStatus(String status) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      alarmKitChannel,
      (call) async {
        if (call.method == 'authorizationStatus' || call.method == 'requestAuthorization') {
          return status;
        }
        return true; // cancel/cancelAll 등은 성공으로 응답한다.
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    awesomeCalls.clear();
    // awesome_notifications는 호스트 OS(macOS)에서는 기본적으로 no-op
    // 구현(AwesomeNotificationsEmpty)을 쓴다 — 실제 MethodChannel로
    // 라우팅되게 강제해야 아래 mock 핸들러가 의미가 있다.
    AwesomeNotificationsPlatform.operatingSystem = 'android';
    AwesomeNotificationsPlatform.resetInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      awesomeChannel,
      (call) async {
        awesomeCalls.add(call.method);
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      alarmKitChannel,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      awesomeChannel,
      null,
    );
    AwesomeNotificationsPlatform.resetInstance();
  });

  AwesomeReminderScheduler buildLocal() => AwesomeReminderScheduler(
    notificationIdsKeyFor: (id) => 'notification_ids_$id',
    deviceNotificationsAllowed: () async => true,
  );

  final emptyAlarm = MedicineAlarm(id: 'a1', name: '약', times: const [], days: const []);

  test('AlarmKit이 notSupported/denied면 로컬 알림 전략을 고른다', () async {
    await setAlarmKitStatus('notSupported');
    final selector = ReminderSchedulerSelector(
      local: buildLocal(),
      alarmKit: AlarmKitReminderScheduler(channel: alarmKitChannel),
      forceIOS: true,
    );

    expect(await selector.currentStrategy(), ReminderStrategy.iosLocalNotification);
  });

  test('AlarmKit이 authorized면 AlarmKit 전략을 고른다', () async {
    await setAlarmKitStatus('authorized');
    final selector = ReminderSchedulerSelector(
      local: buildLocal(),
      alarmKit: AlarmKitReminderScheduler(channel: alarmKitChannel),
      forceIOS: true,
    );

    expect(await selector.currentStrategy(), ReminderStrategy.iosAlarmKit);
  });

  test('전략이 로컬 알림 → AlarmKit으로 바뀌면 로컬 알림 예약을 전부 취소한다', () async {
    final selector = ReminderSchedulerSelector(
      local: buildLocal(),
      alarmKit: AlarmKitReminderScheduler(channel: alarmKitChannel),
      forceIOS: true,
    );

    await setAlarmKitStatus('notSupported');
    await selector.schedule(emptyAlarm);
    expect(awesomeCalls, isNot(contains('cancelAllNotifications')));

    // AlarmKit이 허용되면 전략이 바뀌었음을 감지하고 로컬 알림 쪽을 전부
    // 취소해야 한다(이중 알람 방지, plan §6 W4 3c).
    await setAlarmKitStatus('authorized');
    await selector.schedule(emptyAlarm);
    expect(awesomeCalls, contains('cancelAllNotifications'));
    expect(awesomeCalls, contains('cancelAllSchedules'));
  });
}
