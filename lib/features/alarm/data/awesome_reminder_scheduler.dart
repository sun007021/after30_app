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
  /// 구독해 `AppToast`로 보여준다. 예산 초과 "상태가 바뀔 때"만
  /// 호출한다(리뷰 M4 — 매 포그라운드 복귀마다 반복 알리지 않는다).
  final void Function(String message)? onBudgetWarning;

  static const String actionKeyMarkTaken = 'SNOOZE_10';
  static const String actionKeyCheckOthers = 'CHECK_OTHERS';
  static const String _nextNotificationIdKey = 'alarm_next_notification_id';
  static const String _iosManagedIdsKey = 'reminder_ios_managed_alarm_ids';
  static const int _maxNotificationId = 2000000; // 32비트 정수 범위 내 안전 상한
  static const String _medicineAlarmsChannelKey = 'medicine_alarms';

  int _nextNotificationId = 1;

  /// 카운터 복원 작업 자체를 메모이즈한다(단순 bool 플래그가 아니라
  /// Future를 캐싱) — bool 플래그는 await 이전에 true로 설정되면 동시에
  /// 들어온 두 번째 호출이 복원이 끝나기 전에 카운터를 읽어 같은 값을
  /// 할당해 버릴 수 있다(리뷰 M3 "counter restore" 경쟁 상태).
  Future<void>? _restoreFuture;

  /// iOS에서 마지막으로 계산한 예산 초과 여부. 이 값이 바뀔 때만
  /// [onBudgetWarning]을 호출한다(리뷰 M4).
  bool _lastIosOverBudget = false;

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

  /// 알람 하나를 완전히 제거한다(표시된 알림 dismiss + 예약 취소 +
  /// 저장된 id 목록도 비움). 삭제/비활성화/전략 전환처럼 "이 알람은 이제
  /// 정말로 없다"는 경우에만 쓴다. 내부 재스케줄링에서 "다시 등록할
  /// 예정이니 id는 재사용하겠다"는 경우에는 [_cancelSchedulesOnly]를
  /// 대신 쓴다(리뷰 M1).
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

  Future<void> _ensureIdCounterRestored() {
    return _restoreFuture ??= _restoreIdCounter();
  }

  Future<void> _restoreIdCounter() async {
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

  /// 예약만 취소하고(표시된 알림은 건드리지 않고) 저장된 id 목록은
  /// 그대로 둔다 — 재스케줄링 직전에 "곧 같은 id로 다시 만들 것"이라는
  /// 전제로 쓴다(리뷰 M1). `dismiss`가 아니라 `cancelSchedule`만 호출하므로
  /// 잠금화면/알림 센터에 이미 전달된 알림은 지워지지 않는다(M4).
  Future<void> _cancelSchedulesOnly(List<int> ids) async {
    for (final id in ids) {
      try {
        await AwesomeNotifications().cancelSchedule(id);
      } catch (e) {
        print('알림 예약 취소 실패(id=$id): $e');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Android: 기존 로직 그대로(동작 변화 없음) + id 재사용 버그 수정(M1)
  // ---------------------------------------------------------------------

  Future<void> _scheduleAndroid(MedicineAlarm alarm) async {
    // 기존 id를 재사용해야 하므로 취소 "전에" 먼저 읽는다(리뷰 M1 —
    // 이전에는 `cancel()`이 저장된 목록을 `[]`로 지운 "다음에" 읽어서
    // 항상 새 id가 발급되고 있었다).
    final existingIds = await _existingIdsFor(alarm.id);
    await _cancelSchedulesOnly(existingIds);

    final allowed = await deviceNotificationsAllowed();
    if (!allowed) {
      await _saveIdsFor(alarm.id, const []);
      print('   ⏸️ 디바이스 알람 비활성화 - 스케줄링 건너뜀');
      return;
    }

    final notificationIds = <int>[];
    var idIndex = 0;

    for (final day in alarm.days) {
      for (final time in alarm.times) {
        final notificationId = idIndex < existingIds.length
            ? existingIds[idIndex]
            : await _allocateNextNotificationId();
        await AwesomeNotifications().createNotification(
          content: buildAndroidNotificationContent(
            alarm: alarm,
            day: day,
            time: time,
            notificationId: notificationId,
          ),
          actionButtons: buildReminderActionButtons(),
          schedule: buildAndroidNotificationCalendar(day: day, time: time),
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

    // 예산은 알람 전체에 걸쳐 있어 알람 하나만 부분적으로 갱신할 수
    // 없다 — 채널 전체의 "예약"만 한 번에 취소한다(리뷰 M3: 알람별로
    // 저장된 id만 취소하면 동시 호출/드리프트로 추적되지 않는 예약이
    // 남을 수 있다). `cancelSchedulesByChannelKey`는 예약만 지우고
    // 이미 표시(전달)된 알림은 건드리지 않는다(리뷰 M4 — 매 포그라운드
    // 복귀마다 잠금화면/알림 센터의 알림이 사라지는 문제 방지).
    try {
      await AwesomeNotifications().cancelSchedulesByChannelKey(_medicineAlarmsChannelKey);
    } catch (e) {
      print('iOS 알림 재계산 취소 실패: $e');
    }

    final allowed = await deviceNotificationsAllowed();
    if (!allowed) {
      for (final alarm in allAlarms) {
        await _saveIdsFor(alarm.id, const []);
      }
      return;
    }

    final totalCost = ReminderBudgetPlanner.totalRequestCost(active);
    final isOverBudget = totalCost > ReminderBudgetPlanner.iosPendingLimit;
    if (!isOverBudget) {
      await _scheduleIosWithinBudget(active);
    } else {
      await _scheduleIosBudgeted(active);
      if (!_lastIosOverBudget) {
        onBudgetWarning?.call(
          '알람이 너무 많아 iOS 알림 ${ReminderBudgetPlanner.iosPendingLimit}건 한도에 맞춰 '
          '가까운 일정만 예약했어요. 오래된 알림이 지나면 자동으로 다음 일정이 채워집니다.',
        );
      }
    }
    _lastIosOverBudget = isOverBudget;

    // 활성 목록에서 빠진(방금 비활성화/삭제된) 알람의 저장된 id 목록도
    // 비운다 — 스케줄 자체는 위에서 채널 단위로 이미 전부 취소했다.
    final activeIds = active.map((a) => a.id).toSet();
    for (final alarm in allAlarms) {
      if (!activeIds.contains(alarm.id)) {
        await _saveIdsFor(alarm.id, const []);
      }
    }

    // 리뷰 M10: 예산 초과로 이번 회차엔 알림 id가 없는([]) 알람이라도,
    // "이번 재계산에서 실제로 다뤘다"는 사실은 따로 기록해 둔다 —
    // `hasScheduledNotifications`가 이 기록을 봐서 예산 때문에 빠진
    // 알람과 아직 한 번도 등록된 적 없는 알람(새 기기/재설치 복구
    // 대상)을 구분할 수 있게 한다.
    await _saveManagedIds(activeIds);
  }

  Future<void> _saveManagedIds(Set<String> alarmIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_iosManagedIdsKey, alarmIds.toList());
    } catch (e) {
      print('iOS 관리 알람 id 저장 실패: $e');
    }
  }

  /// 이 알람이 "현재 전략(iOS 로컬 알림)이 최근 재계산에서 이미 다룬"
  /// 알람인지 확인한다(리뷰 M10). 예산 초과로 알림 id가 없어도([])
  /// 이미 관리 중이면 true — `AlarmService.hasScheduledNotifications`가
  /// 새 기기/재설치 복구가 필요한 알람과 구분하는 데 쓴다. 이 기록은
  /// `_rescheduleIos`(iOS 전용)에서만 채워지므로 다른 플랫폼에서는
  /// 항상 비어 있어 자연히 false다 — 별도 플랫폼 분기를 두지 않는다
  /// (단위 테스트에서 직접 검증할 수 있게 하기 위함이기도 하다).
  Future<bool> isManagedByCurrentIosPass(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_iosManagedIdsKey) ?? const [];
      return ids.contains(alarmId);
    } catch (_) {
      return false;
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
            content: buildIosNotificationContent(
              alarm: alarm,
              // 매일 반복(요일 없음)은 특정 요일 하나로 표시하면 실제
              // 발생 요일과 어긋날 수 있어 '매일'로 표시한다(리뷰 m7).
              day: day ?? '매일',
              time: time,
              notificationId: id,
            ),
            actionButtons: buildReminderActionButtons(),
            schedule: buildIosNotificationCalendar(day: day, time: time),
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
        content: buildIosOccurrenceNotificationContent(
          occurrence: occurrence,
          notificationId: id,
        ),
        actionButtons: buildReminderActionButtons(),
        // 예산 초과 시에는 1회성(specific date)으로 예약하고, 다음 앱
        // 포그라운드 진입 때 다시 이 계산을 돌려 창을 앞으로 굴린다.
        schedule: NotificationCalendar.fromDate(date: occurrence.nextFireAt),
      );
      (idsByAlarm[occurrence.alarmId] ??= []).add(id);
    }
    for (final alarm in alarms) {
      await _saveIdsFor(alarm.id, idsByAlarm[alarm.id] ?? const []);
    }
  }
}

/// 알림 payload(알람 탭/액션 처리 시 `AlarmService._onNotificationTapped`가
/// 읽는 필드). Android/iOS 공용이며 순수 함수라 플랫폼 채널 없이
/// 단위 테스트할 수 있다.
@visibleForTesting
Map<String, String> buildReminderPayload({
  required String alarmId,
  required String medicineName,
  required String day,
  required TimeOfDay time,
  required int notificationId,
}) {
  return {
    'alarmId': alarmId,
    'medicineName': medicineName,
    'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    'day': day,
    'notificationId': '$notificationId',
    'fs': '1',
  };
}

/// "복용 완료"(백그라운드)/"이외 약 체크"(포그라운드) 액션 버튼. Android/iOS
/// 공용이며, 순수 값 객체 생성이라 플랫폼 채널 없이 `.toMap()`으로 검증할
/// 수 있다.
@visibleForTesting
List<NotificationActionButton> buildReminderActionButtons() {
  return [
    NotificationActionButton(
      key: AwesomeReminderScheduler.actionKeyMarkTaken,
      label: '복용 완료',
      actionType: ActionType.SilentAction,
    ),
    NotificationActionButton(
      key: AwesomeReminderScheduler.actionKeyCheckOthers,
      label: '이외 약 체크',
    ),
  ];
}

/// Android 알림 콘텐츠(기존 동작 그대로: 풀스크린/웨이크업/잠금화면 위 표시).
@visibleForTesting
NotificationContent buildAndroidNotificationContent({
  required MedicineAlarm alarm,
  required String day,
  required TimeOfDay time,
  required int notificationId,
}) {
  return NotificationContent(
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
    payload: buildReminderPayload(
      alarmId: alarm.id,
      medicineName: alarm.name,
      day: day,
      time: time,
      notificationId: notificationId,
    ),
  );
}

/// Android 반복 예약(요일×시간마다 1건, 기존 동작 그대로).
@visibleForTesting
NotificationCalendar buildAndroidNotificationCalendar({
  required String day,
  required TimeOfDay time,
}) {
  return NotificationCalendar(
    weekday: kKoreanDayToIsoWeekday[day] ?? 1,
    hour: time.hour,
    minute: time.minute,
    second: 0,
    repeats: true,
    preciseAlarm: true,
    allowWhileIdle: true,
  );
}

/// iOS 알림 콘텐츠(예산 이내: fullScreenIntent/wakeUpScreen/locked 없음 —
/// Android 전용 플래그를 무시한다).
@visibleForTesting
NotificationContent buildIosNotificationContent({
  required MedicineAlarm alarm,
  required String day,
  required TimeOfDay time,
  required int notificationId,
}) {
  return NotificationContent(
    id: notificationId,
    channelKey: 'medicine_alarms',
    title: '약 복용 알람',
    body: '${alarm.name} 복용 시간입니다!',
    notificationLayout: NotificationLayout.Default,
    autoDismissible: false,
    category: NotificationCategory.Alarm,
    displayOnBackground: true,
    displayOnForeground: true,
    payload: buildReminderPayload(
      alarmId: alarm.id,
      medicineName: alarm.name,
      day: day,
      time: time,
      notificationId: notificationId,
    ),
  );
}

/// iOS 반복 예약. `day`가 null이면 7일 전체 선택을 매일 반복 1건으로 합친
/// 것이다(weekday 조건 없음).
@visibleForTesting
NotificationCalendar buildIosNotificationCalendar({
  required String? day,
  required TimeOfDay time,
}) {
  return NotificationCalendar(
    weekday: day == null ? null : (kKoreanDayToIsoWeekday[day] ?? 1),
    hour: time.hour,
    minute: time.minute,
    second: 0,
    repeats: true,
    allowWhileIdle: true,
  );
}

/// 64개 예산 초과 시 1회성으로 예약하는 iOS 알림 콘텐츠.
@visibleForTesting
NotificationContent buildIosOccurrenceNotificationContent({
  required ReminderOccurrence occurrence,
  required int notificationId,
}) {
  return NotificationContent(
    id: notificationId,
    channelKey: 'medicine_alarms',
    title: '약 복용 알람',
    body: '${occurrence.medicineName} 복용 시간입니다!',
    notificationLayout: NotificationLayout.Default,
    autoDismissible: false,
    category: NotificationCategory.Alarm,
    displayOnBackground: true,
    displayOnForeground: true,
    payload: buildReminderPayload(
      alarmId: occurrence.alarmId,
      medicineName: occurrence.medicineName,
      day: occurrence.dayKor,
      time: TimeOfDay(hour: occurrence.hour, minute: occurrence.minute),
      notificationId: notificationId,
    ),
  );
}
