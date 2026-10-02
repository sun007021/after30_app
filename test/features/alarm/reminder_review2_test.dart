import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler_selector.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// PR #34 2차 리뷰 회귀 테스트.
/// - Major 1: 스케줄링 호출은 앞 호출이 오래 걸려도 겹쳐 실행되지 않는다.
/// - Major 2, 3: 실제 앱 구성(AlarmService.buildScheduler)에서 AlarmKit이
///   디바이스 알람 설정을 존중하고, 선택기에 활성 알람 공급자가 연결된다.
/// - m1: Android는 알람을 껐다 켜도 같은 알림 id를 다시 쓴다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const alarmKitChannel = MethodChannel('after30/alarmkit');
  const awesomeChannel = MethodChannel('awesome_notifications');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MedicineAlarm alarm(String id) => MedicineAlarm(
    id: id,
    name: '약$id',
    times: const [TimeOfDay(hour: 8, minute: 0)],
    days: const ['월'],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AwesomeNotificationsPlatform.operatingSystem = 'android';
    AwesomeNotificationsPlatform.resetInstance();
    messenger.setMockMethodCallHandler(awesomeChannel, (call) async => true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(alarmKitChannel, null);
    messenger.setMockMethodCallHandler(awesomeChannel, null);
    AwesomeNotificationsPlatform.resetInstance();
  });

  test('앞 스케줄 호출이 오래 걸려도 다음 호출은 끝날 때까지 기다린다(Major 1)', () async {
    final events = <String>[];
    messenger.setMockMethodCallHandler(alarmKitChannel, (call) async {
      if (call.method == 'authorizationStatus') return 'authorized';
      if (call.method == 'schedule') {
        final id = (call.arguments as Map)['scheduleId'];
        events.add('start:$id');
        // 첫 호출만 느리게 만든다. 예전 구현은 앞 링크가 제한 시간을
        // 넘기면 다음 링크를 함께 실행했다.
        if (id == 'a') await Future<void>.delayed(const Duration(milliseconds: 300));
        events.add('end:$id');
        return true;
      }
      return true;
    });
    final selector = ReminderSchedulerSelector(
      local: AwesomeReminderScheduler(
        notificationIdsKeyFor: (id) => 'notification_ids_$id',
        deviceNotificationsAllowed: () async => true,
      ),
      alarmKit: AlarmKitReminderScheduler(channel: alarmKitChannel),
      forceIOS: true,
    );

    final first = selector.schedule(alarm('a'));
    final second = selector.schedule(alarm('b'));
    await Future.wait([first, second]);

    expect(events, ['start:a', 'end:a', 'start:b', 'end:b']);
  });

  test('직렬화 대기열이 비면 다음 호출도 바로 실행된다(교착 없음)', () async {
    messenger.setMockMethodCallHandler(alarmKitChannel, (call) async {
      if (call.method == 'authorizationStatus') return 'authorized';
      return true;
    });
    final selector = ReminderSchedulerSelector(
      local: AwesomeReminderScheduler(
        notificationIdsKeyFor: (id) => 'notification_ids_$id',
        deviceNotificationsAllowed: () async => true,
      ),
      alarmKit: AlarmKitReminderScheduler(channel: alarmKitChannel),
      forceIOS: true,
    );

    await selector.schedule(alarm('a'));
    // 앞 호출이 끝난 뒤의 호출이 이미 끝난 Future를 기다리며 멈추지 않는다.
    await selector.schedule(alarm('b')).timeout(const Duration(seconds: 2));
  });

  group('실제 앱 구성(AlarmService.buildScheduler)', () {
    test('iOS 구성은 선택기에 활성 알람 공급자를 연결한다(Major 3, M6)', () {
      final selector = AlarmService.buildScheduler(
        isIOS: true,
        activeAlarms: () async => [alarm('a')],
      );
      expect(selector.activeAlarmsProvider, isNotNull);
      expect(selector.alarmKit, isNotNull);
    });

    test('디바이스 알람을 끄면 AlarmKit에 알람을 등록하지 않는다(Major 2, M5)', () async {
      SharedPreferences.setMockInitialValues({'allow_device_notifications': false});
      final calls = <String>[];
      messenger.setMockMethodCallHandler(alarmKitChannel, (call) async {
        calls.add(call.method);
        if (call.method == 'authorizationStatus') return 'authorized';
        return true;
      });
      final selector = AlarmService.buildScheduler(
        isIOS: true,
        activeAlarms: () async => [alarm('a')],
      );
      // 테스트 채널로 바꿔 끼운 AlarmKit 스케줄러와 같은 설정 공급자를 쓰는지
      // 확인하려면 실제 구성 객체를 그대로 써야 한다.
      expect(selector.alarmKit, isNotNull);

      await selector.alarmKit!.schedule(alarm('a'));

      expect(calls, isNot(contains('schedule')));
      expect(calls, contains('cancel'));
    });

    test('Android 구성에는 AlarmKit이 없다', () {
      final selector = AlarmService.buildScheduler(isIOS: false);
      expect(selector.alarmKit, isNull);
    });
  });

  test('Android: 알람을 껐다 켜도 같은 알림 id를 다시 쓴다(2차 m1)', () async {
    SharedPreferences.setMockInitialValues({
      'notification_ids_a': ['5'],
      'alarm_next_notification_id': 100,
    });
    final local = AwesomeReminderScheduler(
      notificationIdsKeyFor: (id) => 'notification_ids_$id',
      deviceNotificationsAllowed: () async => true,
    );

    await local.cancel('a');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('notification_ids_a'), ['5'], reason: 'cancel은 id 목록을 비우지 않는다');

    await local.schedule(alarm('a'));
    expect(prefs.getStringList('notification_ids_a'), ['5']);
  });
}
