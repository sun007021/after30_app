import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_budget_planner.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// `AwesomeReminderScheduler`가 실제로 만드는 `NotificationContent` /
/// `NotificationCalendar` / `NotificationActionButton` "모양"을 검증한다.
/// 이 값 객체들은 플랫폼 채널 없이 순수하게 만들 수 있어서(`.toMap()`),
/// awesome_notifications 플러그인을 목(mock)하지 않고도 Android 페이로드가
/// 리팩터링 전후로 바뀌지 않았는지(회귀), iOS 분기가 요구사항대로
/// 동작하는지 확인할 수 있다.
void main() {
  final alarm = MedicineAlarm(
    id: 'sched-1',
    name: '혈압약',
    times: const [TimeOfDay(hour: 8, minute: 30)],
    days: const ['월', '화', '수', '목', '금', '토', '일'],
  );

  group('Android 페이로드(회귀 — 리팩터링 전후 동일해야 함)', () {
    test('NotificationContent: fullScreenIntent/wakeUpScreen/locked가 그대로 켜져 있다', () {
      final content = buildAndroidNotificationContent(
        alarm: alarm,
        day: '월',
        time: const TimeOfDay(hour: 8, minute: 30),
        notificationId: 42,
      );

      expect(content.id, 42);
      expect(content.channelKey, 'medicine_alarms');
      expect(content.title, '약 복용 알람');
      expect(content.body, '혈압약 복용 시간입니다!');
      expect(content.wakeUpScreen, isTrue);
      expect(content.fullScreenIntent, isTrue);
      expect(content.locked, isTrue);
      expect(content.autoDismissible, isFalse);
      expect(content.category, NotificationCategory.Alarm);
      expect(content.displayOnBackground, isTrue);
      expect(content.displayOnForeground, isTrue);
      expect(content.payload, {
        'alarmId': 'sched-1',
        'medicineName': '혈압약',
        'time': '08:30',
        'day': '월',
        'notificationId': '42',
        'fs': '1',
      });
    });

    test('NotificationCalendar: 요일마다 preciseAlarm/allowWhileIdle 반복 예약이다', () {
      final calendar = buildAndroidNotificationCalendar(
        day: '금',
        time: const TimeOfDay(hour: 20, minute: 0),
      );
      expect(calendar.weekday, 5);
      expect(calendar.hour, 20);
      expect(calendar.minute, 0);
      expect(calendar.repeats, isTrue);
      expect(calendar.preciseAlarm, isTrue);
      expect(calendar.allowWhileIdle, isTrue);
    });

    test('액션 버튼: 복용 완료는 SilentAction(백그라운드), 이외 약 체크는 기본(포그라운드)이다', () {
      final buttons = buildReminderActionButtons();
      expect(buttons, hasLength(2));
      expect(buttons[0].key, AwesomeReminderScheduler.actionKeyMarkTaken);
      expect(buttons[0].actionType, ActionType.SilentAction);
      expect(buttons[1].key, AwesomeReminderScheduler.actionKeyCheckOthers);
      expect(buttons[1].actionType, ActionType.Default);
    });
  });

  group('iOS 알림 콘텐츠/캘린더(Android 전용 플래그 무시 + 매일 반복 합침)', () {
    test('NotificationContent에는 fullScreenIntent/wakeUpScreen/locked가 없다', () {
      final content = buildIosNotificationContent(
        alarm: alarm,
        day: '월',
        time: const TimeOfDay(hour: 8, minute: 30),
        notificationId: 7,
      );
      expect(content.fullScreenIntent, isNot(isTrue));
      expect(content.wakeUpScreen, isNot(isTrue));
      expect(content.locked, isNot(isTrue));
      expect(content.category, NotificationCategory.Alarm);
    });

    test('7일 전체 선택은 weekday가 null인 매일 반복 1건으로 합쳐진다', () {
      final calendar = buildIosNotificationCalendar(
        day: null,
        time: const TimeOfDay(hour: 8, minute: 30),
      );
      expect(calendar.weekday, isNull);
      expect(calendar.repeats, isTrue);
    });

    test('일부 요일만 선택하면 weekday가 지정된다', () {
      final calendar = buildIosNotificationCalendar(
        day: '화',
        time: const TimeOfDay(hour: 9, minute: 0),
      );
      expect(calendar.weekday, 2);
    });
  });

  group('예산 초과 시 1회성 알림(occurrence) 콘텐츠', () {
    test('payload에 알람 정보가 정확히 들어간다', () {
      final occurrence = ReminderOccurrence(
        alarmId: 'sched-9',
        medicineName: '영양제',
        dayKor: '수',
        hour: 12,
        minute: 5,
        nextFireAt: DateTime(2026, 9, 23, 12, 5),
      );
      final content = buildIosOccurrenceNotificationContent(
        occurrence: occurrence,
        notificationId: 99,
      );
      expect(content.payload, {
        'alarmId': 'sched-9',
        'medicineName': '영양제',
        'time': '12:05',
        'day': '수',
        'notificationId': '99',
        'fs': '1',
      });
    });
  });
}
