import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/reminder_budget_planner.dart';
import 'package:after30/features/alarm/data/reminder_scheduler.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// awesome_notifications 기반 스케줄러(plan §6 W4 1항).
///
/// - **Android**(전 버전) 및 **iOS 16~25**(또는 iOS 26+이지만 AlarmKit 권한이
///   없는 경우)에서 쓴다.
/// - Android 분기는 `AlarmService`에 있던 기존 로직을 동작 변화 없이
///   그대로 옮긴 것이다(fullScreenIntent/wakeUpScreen/locked/preciseAlarm 유지).
/// - iOS 분기는 Android 전용 플래그를 무시하고, 7일 전체 선택 시 요일 없는
///   매일 반복 1건으로 합치며, 64개 대기 예산을 넘지 않도록 관리한다
///   (plan §1.3, §7).
class AwesomeReminderScheduler implements ReminderScheduler {
  AwesomeReminderScheduler({
    required this.notificationIdsKeyFor,
    required this.deviceNotificationsAllowed,
    this.onBudgetWarning,
  });

  /// 알람 ID를 (사용자 네임스페이스가 반영된) SharedPreferences 키로 바꾼다.
  /// `AlarmService`가 기존과 동일한 키 스킴을 유지하도록 주입한다.
  final String Function(String alarmId) notificationIdsKeyFor;

  /// 사용자가 "디바이스 알람"을 꺼뒀는지(기존 MySettingsStore 설정).
  final Future<bool> Function() deviceNotificationsAllowed;

  /// iOS 64개 예산을 초과해 일부 알람이 잘렸을 때 1회성으로 알리는 콜백
  /// (plan §6 W4 2항 "안내 토스트"). UI(W5)가 `AlarmService`를 통해
  /// 구독해 `AppToast`로 보여준다.
  final void Function(String message)? onBudgetWarning;

  static const String actionKeyMarkTaken = 'SNOOZE_10';
  static const String actionKeyCheckOthers = 'CHECK_OTHERS';
  static const String _nextNotificationIdKey = 'alarm_next_notification_id';
  static const int _maxNotificationId = 2000000; // 32비트 정수 범위 내 안전 상한

  int _nextNotificationId = 1;
  bool _idCounterRestored = false;

  bool get _isIos => Platform.isIOS;

  // ---------------------------------------------------------------------
  // ReminderScheduler 구현
  // ---------------------------------------------------------------------

  @override
  Future<bool> schedule(MedicineAlarm alarm) async {
    try {
      if (_isIos) {
        // iOS는 64개 예산이 알람 전체에 걸쳐 있으므로, 알람 하나만 바꿔도
        // 전체를 다시 계산해야 한다(rescheduleAll로 위임).
        await _rescheduleIos(await activeAlarmsProviderOrEmpty(alarm));
        return true;
      }
      await _scheduleAndroid(alarm);
      return true;
    } catch (e) {
      print('❌ 알람 스케줄링 실패: $e');
      return false;
    }
  }

  /// 이 알람을 반드시 포함한 활성 알람 목록을 넘겨받아야 하므로,
  /// `AlarmService`가 저장 후 호출한다는 전제 하에 [activeAlarmsProvider]를
  /// 쓴다. 주입되지 않았다면(테스트 등) 이 알람 하나만으로 계산한다.
  Future<List<MedicineAlarm>> activeAlarmsProviderOrEmpty(MedicineAlarm alarm) async {
    if (activeAlarmsProvider == null) return alarm.isActive ? [alarm] : [];
    final all = await activeAlarmsProvider!();
    if (all.any((a) => a.id == alarm.id)) return all;
    return [...all, if (alarm.isActive) alarm];
  }

  /// 저장소 기준 활성 알람 전체를 읽어오는 콜백(`AlarmService.getAlarms`를
  /// 감싼 것). 생성 이후에 지정할 수 있게 세터로 둔다(순환 의존 방지).
  Future<List<MedicineAlarm>> Function()? activeAlarmsProvider;

  @override
  Future<void> cancel(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = notificationIdsKeyFor(alarmId);
      final ids = prefs.getStringList(key);
      if (ids != null) {
        for (final idString in ids) {
          final id = int.tryParse(idString);
          if (id != null) {
            await AwesomeNotifications().cancel(id);
          }
        }
      }
      await prefs.setStringList(key, const []);
    } catch (e) {
      print('알람 취소 실패: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
    await AwesomeNotifications().cancelAllSchedules();
  }

  @override
  Future<void> rescheduleAll(List<MedicineAlarm> activeAlarms) async {
    if (_isIos) {
      await _rescheduleIos(activeAlarms);
      return;
    }
    for (final alarm in activeAlarms) {
      await _scheduleAndroid(alarm);
    }
  }

  @override
  Future<ReminderBudgetStatus> pendingBudget() async {
    if (!_isIos) return ReminderBudgetStatus.unlimited;
    try {
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      return ReminderBudgetStatus(
        used: scheduled.length,
        capacity: ReminderBudgetPlanner.iosPendingLimit,
      );
    } catch (e) {
      print('예약 알림 개수 조회 실패: $e');
      return const ReminderBudgetStatus(used: 0, capacity: ReminderBudgetPlanner.iosPendingLimit);
    }
  }

  // ---------------------------------------------------------------------
  // 알림 ID 카운터(awesome_notifications 정수 ID 발급/영속화)
  // ---------------------------------------------------------------------

  Future<void> _ensureIdCounterRestored() async {
    if (_idCounterRestored) return;
    _idCounterRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_nextNotificationIdKey);
      if (stored != null && stored > 0) {
        _nextNotificationId = stored;
      }
      var maxExisting = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('notification_ids_')) {
          final ids = prefs.getStringList(key) ?? const [];
          for (final idString in ids) {
            final id = int.tryParse(idString);
            if (id != null && id > maxExisting) {
              maxExisting = id;
            }
          }
        }
      }
      if (_nextNotificationId <= maxExisting) {
        _nextNotificationId = maxExisting + 1;
      }
      if (_nextNotificationId > _maxNotificationId || _nextNotificationId < 1) {
        _nextNotificationId = 1;
      }
      await prefs.setInt(_nextNotificationIdKey, _nextNotificationId);
    } catch (e) {
      print('알림 ID 카운터 복원 실패: $e');
    }
  }

  Future<int> _allocateNextNotificationId() async {
    await _ensureIdCounterRestored();
    final id = _nextNotificationId;
    _nextNotificationId++;
    if (_nextNotificationId > _maxNotificationId) {
      _nextNotificationId = 1;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_nextNotificationIdKey, _nextNotificationId);
    } catch (e) {
      print('알림 ID 카운터 저장 실패: $e');
    }
    return id;
  }

  Future<List<int>> _existingIdsFor(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(notificationIdsKeyFor(alarmId));
      if (ids == null) return [];
      return ids.map((id) => int.parse(id)).toList();
    } catch (e) {
      print('기존 알림 ID 가져오기 실패: $e');
      return [];
    }
  }

  Future<void> _saveIdsFor(String alarmId, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      notificationIdsKeyFor(alarmId),
      ids.map((id) => id.toString()).toList(),
    );
  }

  int _dayIndex(String day) {
    const dayMap = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
    return dayMap[day] ?? 1;
  }

  // ---------------------------------------------------------------------
  // Android: 기존 로직 그대로(동작 변화 없음)
  // ---------------------------------------------------------------------

  Future<void> _scheduleAndroid(MedicineAlarm alarm) async {
    await cancel(alarm.id);

    final allowed = await deviceNotificationsAllowed();
    if (!allowed) {
      await _saveIdsFor(alarm.id, const []);
      print('   ⏸️ 디바이스 알람 비활성화 - 스케줄링 건너뜀');
      return;
    }

    final existingIds = await _existingIdsFor(alarm.id);
    final notificationIds = <int>[];
    var idIndex = 0;

    for (final day in alarm.days) {
      for (final time in alarm.times) {
        final notificationId = idIndex < existingIds.length
            ? existingIds[idIndex]
            : await _allocateNextNotificationId();
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'medicine_alarms',
            title: '약 복용 알람',
            body: '${alarm.name} 복용 시간입니다!',
            notificationLayout: NotificationLayout.Default,
            wakeUpScreen: true,
            fullScreenIntent: true,
            autoDismissible: false,
            locked: true,
            category: NotificationCategory.Alarm,
            displayOnBackground: true,
            displayOnForeground: true,
            payload: _payloadFor(alarm, day, time, notificationId),
          ),
          actionButtons: _actionButtons(),
          schedule: NotificationCalendar(
            weekday: _dayIndex(day),
            hour: time.hour,
            minute: time.minute,
            second: 0,
            repeats: true,
            preciseAlarm: true,
            allowWhileIdle: true,
          ),
        );
        notificationIds.add(notificationId);
        idIndex++;
      }
    }
    await _saveIdsFor(alarm.id, notificationIds);
  }

  // ---------------------------------------------------------------------
  // iOS 16~25(및 AlarmKit 미허용 iOS 26+): 요일 반복은 유지하되 7일 선택은
  // 매일 반복 1건으로 합치고, 64개 예산을 넘으면 가까운 발생분만 1회성으로
  // 예약한다(plan §6 W4 2항).
  // ---------------------------------------------------------------------

  Future<void> _rescheduleIos(List<MedicineAlarm> allAlarms) async {
    final active = allAlarms.where((a) => a.isActive).toList();

    // 이전에 등록했던 모든 예약을 정리하고 처음부터 다시 계산한다(예산은
    // 알람 전체에 걸쳐 있어 알람 하나만 부분적으로 갱신할 수 없다).
    for (final alarm in allAlarms) {
      await cancel(alarm.id);
    }

    final allowed = await deviceNotificationsAllowed();
    if (!allowed) return;

    final totalCost = ReminderBudgetPlanner.totalRequestCost(active);
    if (totalCost <= ReminderBudgetPlanner.iosPendingLimit) {
      await _scheduleIosWithinBudget(active);
    } else {
      await _scheduleIosBudgeted(active);
    }
  }

  Future<void> _scheduleIosWithinBudget(List<MedicineAlarm> alarms) async {
    for (final alarm in alarms) {
      final ids = <int>[];
      final isDaily = alarm.days.toSet().length >= 7;
      final List<String?> days = isDaily ? [null] : alarm.days.toSet().toList();
      for (final day in days) {
        for (final time in alarm.times) {
          final id = await _allocateNextNotificationId();
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: id,
              channelKey: 'medicine_alarms',
              title: '약 복용 알람',
              body: '${alarm.name} 복용 시간입니다!',
              notificationLayout: NotificationLayout.Default,
              autoDismissible: false,
              category: NotificationCategory.Alarm,
              displayOnBackground: true,
              displayOnForeground: true,
              payload: _payloadFor(alarm, day ?? alarm.days.first, time, id),
            ),
            actionButtons: _actionButtons(),
            schedule: NotificationCalendar(
              weekday: day == null ? null : _dayIndex(day),
              hour: time.hour,
              minute: time.minute,
              second: 0,
              repeats: true,
              allowWhileIdle: true,
            ),
          );
          ids.add(id);
        }
      }
      await _saveIdsFor(alarm.id, ids);
    }
  }

  Future<void> _scheduleIosBudgeted(List<MedicineAlarm> alarms) async {
    final occurrences = buildBudgetedOccurrences(
      activeAlarms: alarms,
      now: DateTime.now(),
    );
    final idsByAlarm = <String, List<int>>{};
    for (final occurrence in occurrences) {
      final id = await _allocateNextNotificationId();
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'medicine_alarms',
          title: '약 복용 알람',
          body: '${occurrence.medicineName} 복용 시간입니다!',
          notificationLayout: NotificationLayout.Default,
          autoDismissible: false,
          category: NotificationCategory.Alarm,
          displayOnBackground: true,
          displayOnForeground: true,
          payload: {
            'alarmId': occurrence.alarmId,
            'medicineName': occurrence.medicineName,
            'time':
                '${occurrence.hour.toString().padLeft(2, '0')}:${occurrence.minute.toString().padLeft(2, '0')}',
            'day': occurrence.dayKor,
            'notificationId': '$id',
            'fs': '1',
          },
        ),
        actionButtons: _actionButtons(),
        // 예산 초과 시에는 1회성(specific date)으로 예약하고, 다음 앱
        // 포그라운드 진입 때 다시 이 계산을 돌려 창을 앞으로 굴린다.
        schedule: NotificationCalendar.fromDate(date: occurrence.nextFireAt),
      );
      (idsByAlarm[occurrence.alarmId] ??= []).add(id);
    }
    for (final alarm in alarms) {
      await _saveIdsFor(alarm.id, idsByAlarm[alarm.id] ?? const []);
    }
    onBudgetWarning?.call(
      '알람이 너무 많아 iOS 알림 ${ReminderBudgetPlanner.iosPendingLimit}건 한도에 맞춰 '
      '가까운 일정만 예약했어요. 오래된 알림이 지나면 자동으로 다음 일정이 채워집니다.',
    );
  }

  Map<String, String> _payloadFor(MedicineAlarm alarm, String day, TimeOfDay time, int id) {
    return {
      'alarmId': alarm.id,
      'medicineName': alarm.name,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'day': day,
      'notificationId': '$id',
      'fs': '1',
    };
  }

  List<NotificationActionButton> _actionButtons() {
    return [
      NotificationActionButton(
        key: actionKeyMarkTaken,
        label: '복용 완료',
        actionType: ActionType.SilentAction,
      ),
      NotificationActionButton(key: actionKeyCheckOthers, label: '이외 약 체크'),
    ];
  }
}
