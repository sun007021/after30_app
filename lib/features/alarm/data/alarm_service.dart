import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler_selector.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';
import 'package:after30/features/my/settings_store.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 알람 저장소 + 파사드(plan §6 W4 1항). 기기 스케줄링은
/// [ReminderSchedulerSelector](Android/iOS 로컬 알림/AlarmKit 중 선택)에
/// 위임하고, 이 클래스는 기존 공개 API를 그대로 유지해 화면 코드가 바뀌지
/// 않게 한다.
@pragma('vm:entry-point')
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  static const bool _verboseLogs = false; // 상세 로그 스위치

  static const String _alarmsKeyLegacy = 'medicine_alarms';
  static String? _currentUserId; // 사용자 네임스페이스
  static GlobalKey<NavigatorState>? _navigatorKey; // 전체화면 네비게이션용

  static final ReminderSchedulerSelector _scheduler = ReminderSchedulerSelector(
    local: AwesomeReminderScheduler(
      notificationIdsKeyFor: _notificationIdsKeyForStatic,
      deviceNotificationsAllowed: MySettingsStore.getAllowDeviceNotifications,
      onBudgetWarning: (message) => _budgetWarningController.add(message),
    )..activeAlarmsProvider = () => AlarmService()._activeAlarmsFromStorage(),
  );

  static final StreamController<String> _budgetWarningController =
      StreamController<String>.broadcast();

  /// iOS 64개 예산 초과로 일부 알람이 잘렸을 때 1회성 안내 메시지가
  /// 흘러나오는 스트림(plan §6 W4 2항). UI(W5)가 구독해 `AppToast`로
  /// 보여준다.
  static Stream<String> get budgetWarnings => _budgetWarningController.stream;

  /// 현재 iOS에서 쓰고 있는 전략(디버그 화면/설정 화면 노출용).
  static Future<ReminderStrategy> currentReminderStrategy() =>
      _scheduler.currentStrategy();

  /// AlarmKit 권한/기기 알람 설정 화면(W9 `DeviceAlarmSettings`)이 재사용할
  /// 수 있게 AlarmKit 스케줄러를 노출한다.
  static AlarmKitReminderScheduler? get alarmKitScheduler => _scheduler.alarmKit;

  final _AlarmServiceLifecycleObserver _lifecycleObserver = _AlarmServiceLifecycleObserver();

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // 로그인/앱 시작 시 현재 사용자 설정
  static void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  static String _alarmsKeyForUserStatic() {
    return _currentUserId == null
        ? _alarmsKeyLegacy
        : 'medicine_alarms_$_currentUserId';
  }

  static String _notificationIdsKeyForStatic(String alarmId) {
    return _currentUserId == null
        ? 'notification_ids_$alarmId'
        : 'notification_ids_${_currentUserId}_$alarmId';
  }

  Future<void> initialize() async {
    // 시간대 초기화
    tz.initializeTimeZones();

    // 알림 초기화
    await AwesomeNotifications().initialize(
      null, // null은 기본 아이콘 사용
      [
        NotificationChannel(
          channelKey: 'medicine_alarms',
          channelName: '약 복용 알람',
          channelDescription: '약 복용 시간을 알려주는 알람',
          defaultColor: Colors.pink,
          ledColor: Colors.pink,
          importance: NotificationImportance.Max,
          playSound: true,
          // 시스템 기본 알람 스트림 사용(벨소리 반복은 풀스크린에서 직접 재생)
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          channelShowBadge: true,
          enableVibration: true,
          enableLights: true,
        ),
        // 일반 푸시 알림(FCM) 전용 채널 - 진동 비활성화
        NotificationChannel(
          channelKey: 'push_messages',
          channelName: '푸시 알림',
          channelDescription: '일반 푸시 알림 채널(진동 없음)',
          importance: NotificationImportance.High,
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          playSound: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          channelShowBadge: true,
          enableVibration: false,
          enableLights: true,
        ),
      ],
    );

    // 알림 권한 요청은 여기서 하지 않는다(HIG 위반 — 콜드 런치 시점).
    // 대신 `ReminderPermissionFlow.ensureRequestedAfterLogin`(로그인 직후,
    // Android 기존 동작 재현)과 `requestWithRationale`(첫 약 등록 직전,
    // 사전 설명 후 시스템 프롬프트, iOS 26+는 AlarmKit 권한도 함께)에서
    // 맥락과 함께 요청한다.

    // 알림 액션 리스너 설정
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: AlarmService._onNotificationTapped,
      onNotificationCreatedMethod: AlarmService._onNotificationCreated,
      onNotificationDisplayedMethod: AlarmService._onNotificationDisplayed,
      onDismissActionReceivedMethod: AlarmService._onDismissActionReceived,
    );

    // iOS 로컬 알림 fallback은 64개 예산을 앱 포그라운드 진입마다 앞으로
    // 굴려야 하고(plan §7), AlarmKit "복용 완료" 백그라운드 인텐트가 남긴
    // 완료 기록도 그때 함께 반영한다. Android 동작에는 영향이 없다(가드).
    if (Platform.isIOS) {
      await _drainAlarmKitCompletions();
      await _refreshAlertingAlarmKitState();
      _lifecycleObserver.onResumed = () async {
        await rescheduleAllActiveFromStorage();
        await _drainAlarmKitCompletions();
      };
      WidgetsBinding.instance.addObserver(_lifecycleObserver);
    }
  }

  static String _formatYMD(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _normalizeTimeToHhMmSs(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(s);
    if (m != null) {
      final hh = (m.group(1) ?? '0').padLeft(2, '0');
      final mm = m.group(2) ?? '00';
      final ss = m.group(3) ?? '00';
      return '$hh:$mm:$ss';
    }
    if (RegExp(r'^\d{3,4}$').hasMatch(s)) {
      final p = s.padLeft(4, '0');
      return '${p.substring(0, 2)}:${p.substring(2, 4)}:00';
    }
    return s;
  }

  static String _korDayToEnum(String dayKor) {
    switch (dayKor) {
      case '월':
        return 'MON';
      case '화':
        return 'TUE';
      case '수':
        return 'WED';
      case '목':
        return 'THU';
      case '금':
        return 'FRI';
      case '토':
        return 'SAT';
      case '일':
        return 'SUN';
      default:
        return 'MON';
    }
  }

  // 성공/실패를 반환한다. 스케줄 매칭 실패, API 호출 실패 모두 실패(false)로 취급한다.
  static Future<bool> _markTakenBestEffort({
    required String medicineName,
    required String dayKor,
    required String hhmm,
  }) async {
    try {
      final schedules = await ScheduleService().getSchedules(
        includeInactive: false,
      );
      final dayEnum = _korDayToEnum(dayKor);
      final timeHms = _normalizeTimeToHhMmSs(hhmm);
      int? matchId;
      for (final s in schedules) {
        if (s is! Map<String, dynamic>) continue;
        final name = (s['medication_name'] as String?) ?? '';
        final times = ((s['times'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        final repeatDays = ((s['repeat_days'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        final normalizedTimes = times.map(_normalizeTimeToHhMmSs).toList();
        final everyDay = repeatDays.isEmpty || repeatDays.length == 7;
        final dayOk = everyDay || repeatDays.contains(dayEnum);
        if (name == medicineName &&
            dayOk &&
            normalizedTimes.contains(timeHms)) {
          matchId = (s['id'] as num?)?.toInt();
          if (matchId != null) break;
        }
      }
      if (matchId == null) {
        if (_verboseLogs) {
          print('복용 완료 매칭 실패: name=$medicineName day=$dayEnum time=$timeHms');
        }
        return false;
      }
      final today = DateTime.now();
      await HistoryService().markTaken(
        scheduleId: matchId,
        scheduledDate: _formatYMD(today),
        // 백엔드는 HH:mm 형식을 기대할 수 있어 분 단위로 전달
        scheduledTime: timeHms.substring(0, 5),
      );
      if (_verboseLogs) {
        print('복용 완료 처리 API 호출 성공: scheduleId=$matchId time=$timeHms');
      }
      return true;
    } catch (e) {
      print('복용 완료 API 호출 실패: $e');
      return false;
    }
  }

  // 외부(UI)에서 복용 완료를 호출할 수 있도록 공개 메서드 제공. 성공 여부를 반환한다.
  static Future<bool> markTakenFromUi({
    required String medicineName,
    required String dayKor,
    required String hhmm,
  }) async {
    return _markTakenBestEffort(
      medicineName: medicineName,
      dayKor: dayKor,
      hhmm: hhmm,
    );
  }

  /// AlarmKit "복용 완료" 보조 버튼(백그라운드 LiveActivityIntent)이 앱이
  /// 백그라운드/종료 상태일 때 남겨 둔 완료 기록을 꺼내 처리한다
  /// (plan §6 W4 3b, §7 "백그라운드 액션 실패 시 foreground로 전환" 리스크
  /// 대응은 실기기 검증 후 필요하면 추가한다).
  static Future<void> _drainAlarmKitCompletions() async {
    final alarmKit = _scheduler.alarmKit;
    if (alarmKit == null) return;
    try {
      final completions = await alarmKit.drainCompletions();
      for (final c in completions) {
        final name = (c['medicineName'] as String?) ?? '';
        final day = (c['day'] as String?) ?? '월';
        final hour = (c['hour'] as num?)?.toInt() ?? 0;
        final minute = (c['minute'] as num?)?.toInt() ?? 0;
        final hhmm =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        await _markTakenBestEffort(medicineName: name, dayKor: day, hhmm: hhmm);
      }
    } catch (e) {
      print('AlarmKit 완료 기록 처리 실패: $e');
    }
  }

  /// 지금 AlarmKit 알람이 울리고 있다면 풀스크린 페이지로 이동한다(앱이
  /// 이미 실행 중인 상태에서 알림을 탭해 포그라운드로 온 경우). 콜드
  /// 스타트 경로는 `main.dart`의 `StartupPage`가 직접 조회한다.
  static Future<void> _refreshAlertingAlarmKitState() async {
    final alarmKit = _scheduler.alarmKit;
    final navContext = _navigatorKey?.currentState?.context;
    if (alarmKit == null || navContext == null) return;
    try {
      final alerting = await alarmKit.alertingAlarm();
      if (alerting == null) return;
      final name = (alerting['medicineName'] as String?) ?? '약';
      final day = (alerting['day'] as String?) ?? '월';
      final hour = (alerting['hour'] as num?)?.toInt() ?? 8;
      final minute = (alerting['minute'] as num?)?.toInt() ?? 0;
      final alarmId = alerting['scheduleId'] as String?;
      showFullscreenAlarm(
        navContext,
        MedicineAlarm(
          id: alarmId,
          name: name,
          times: [TimeOfDay(hour: hour, minute: minute)],
          days: [day],
        ),
        TimeOfDay(hour: hour, minute: minute),
        day,
      );
    } catch (e) {
      print('AlarmKit 알림 상태 조회 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationTapped(
    ReceivedAction receivedAction,
  ) async {
    // 알람 탭 시 전체화면 페이지로 이동
    try {
      final pressedKey = receivedAction.buttonKeyPressed;
      final payload = receivedAction.payload ?? {};
      final alarmId = payload['alarmId'] ?? '';
      final name = payload['medicineName'] ?? '약';
      final timeStr = payload['time'] ?? '08:00';
      final day = payload['day'] ?? '월';
      final notifId =
          int.tryParse(payload['notificationId'] ?? '') ??
          receivedAction.id ??
          0;

      final hour = int.tryParse(timeStr.split(':').first) ?? 8;
      final minute = int.tryParse(timeStr.split(':').last) ?? 0;
      final alarm = MedicineAlarm(
        id: alarmId.isEmpty ? null : alarmId,
        name: name,
        times: [TimeOfDay(hour: hour, minute: minute)],
        days: [day],
      );

      // 액션 버튼 처리
      if (pressedKey == AwesomeReminderScheduler.actionKeyMarkTaken) {
        // 복용 완료: 성공한 경우에만 알림을 닫는다. 실패 시(오프라인/서버 거부 등)
        // 알림을 유지해 사용자가 다시 시도할 수 있게 한다.
        try {
          final success = await _markTakenBestEffort(
            medicineName: name,
            dayKor: day,
            hhmm: timeStr,
          );
          if (success) {
            await AwesomeNotifications().cancel(notifId);
            print('복용 완료 처리됨: notificationId=$notifId');
          } else {
            print('복용 완료 처리 실패: 알림 유지 - notificationId=$notifId');
          }
        } catch (e) {
          print('복용 완료 처리 실패: $e');
        }
        return;
      } else if (pressedKey == AwesomeReminderScheduler.actionKeyCheckOthers) {
        // 홈 화면으로 이동
        final state = _navigatorKey?.currentState;
        if (state != null) {
          state.pushNamedAndRemoveUntil('/home', (route) => false);
          return;
        }
      }
      // 기본 동작(버튼 키 없음): 알림 본문을 직접 탭한 경우 풀스크린 알람 화면으로 이동한다.
      // 사용자가 알림을 직접 탭했을 때만 이 경로를 타므로, 포그라운드에서 조작 없이
      // 화면이 튀는 문제(자동 네비게이션 방지 의도)는 발생하지 않는다.
      // 네비게이터가 아직 준비되지 않은 콜드 스타트 상황이면 조용히 무시하고
      // main.dart의 시작 경로가 처리하도록 둔다.
      final navState = _navigatorKey?.currentState;
      final navContext = navState?.context;
      if (navContext != null) {
        showFullscreenAlarm(
          navContext,
          alarm,
          TimeOfDay(hour: hour, minute: minute),
          day,
          notificationId: notifId,
        );
      }
      return;
    } catch (e) {
      print('전체화면 이동 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(
    ReceivedNotification receivedNotification,
  ) async {
    print('알림 생성됨: ${receivedNotification.title}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayed(
    ReceivedNotification receivedNotification,
  ) async {
    print('알림 표시됨: ${receivedNotification.title}');
    // FullScreen Intent 구조: 표시 콜백에서는 네비게이션하지 않음.
    // 안드로이드가 풀스크린 인텐트로 앱을 깨울 때, 앱 시작(initial action)에서 풀스크린 라우트로 이동.
  }

  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceived(
    ReceivedAction receivedAction,
  ) async {
    print('알림 해제됨: ${receivedAction.payload}');
  }

  // 알람 등록
  Future<bool> scheduleAlarm(MedicineAlarm alarm) async {
    try {
      print(
        '🔔 알람 스케줄링: scheduleId=${alarm.id}, name=${alarm.name}, times=${alarm.times.length}, days=${alarm.days.length}',
      );
      // 먼저 저장소에 알람 메타데이터를 반영한다 — iOS 스케줄러는 전체
      // 활성 알람 목록을 다시 읽어 64개 예산을 계산하므로, 이 알람이
      // 이미 저장돼 있어야 한다.
      await _upsertAlarmMetadata(alarm);
      final ok = await _scheduler.schedule(alarm);
      print(ok ? '   ✅ 알람 스케줄링 완료: scheduleId=${alarm.id}' : '   ❌ 알람 스케줄링 실패');
      return ok;
    } catch (e) {
      print('❌ 알람 스케줄링 실패: $e');
      return false;
    }
  }

  // 해당 알람이 이미 기기에 예약돼 있는지 확인(새 기기/재설치 후 동기화용)
  Future<bool> hasScheduledNotifications(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_notificationIdsKeyForStatic(alarmId));
      if (ids != null && ids.isNotEmpty) return true;
    } catch (_) {}
    final alarmKit = _scheduler.alarmKit;
    if (alarmKit != null) {
      final list = await alarmKit.list();
      if (list.any((e) => e['scheduleId'] == alarmId)) return true;
    }
    return false;
  }

  // 알람 메타데이터만 저장(알림 ID는 각 스케줄러가 자체적으로 관리)
  Future<void> _upsertAlarmMetadata(MedicineAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAlarms();
    final existingIndex = alarms.indexWhere((a) => a.id == alarm.id);
    if (existingIndex >= 0) {
      alarms[existingIndex] = alarm;
    } else {
      alarms.add(alarm);
    }
    final alarmsJson = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_alarmsKeyForUserStatic(), json.encode(alarmsJson));
  }

  Future<List<MedicineAlarm>> _activeAlarmsFromStorage() async {
    final alarms = await getAlarms();
    return alarms.where((a) => a.isActive).toList();
  }

  // 알람 취소 (ID는 유지)
  Future<void> cancelAlarm(String alarmId) async {
    await _scheduler.cancel(alarmId);
    print('   ✅ 알림 취소 완료: scheduleId=$alarmId');
  }

  // 활성 알람의 디바이스 스케줄만 취소 (저장 데이터는 유지)
  Future<void> cancelAllActiveAlarmSchedules() async {
    try {
      final alarms = await getAlarms();
      for (final alarm in alarms) {
        if (alarm.isActive) {
          await cancelAlarm(alarm.id);
        }
      }
    } catch (e) {
      print('활성 알람 스케줄 취소 실패: $e');
    }
  }

  // 모든 알람 취소(표시/예약 전부, 모든 전략)
  Future<void> cancelAllAlarms() async {
    await _scheduler.cancelAll();
  }

  // 모든 예약(스케줄)만 취소 — 기존 API 호환을 위해 유지, cancelAllAlarms와 동일하게 위임한다.
  Future<void> cancelAllAlarmSchedules() async {
    await _scheduler.cancelAll();
  }

  // 모든 알람 데이터(스케줄 + 저장소) 정리
  Future<void> clearAllAlarmData() async {
    try {
      await _scheduler.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      // 레거시 키 제거
      await prefs.remove(_alarmsKeyLegacy);
      // 사용자별 키 제거
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith('medicine_alarms_')) {
          await prefs.remove(key);
        }
        if (key.startsWith('notification_ids_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('알람 전체 데이터 정리 실패: $e');
    }
  }

  // 저장된 알람을 불러와 활성화된 항목만 재스케줄
  Future<void> rescheduleAllActiveFromStorage() async {
    try {
      final alarms = await _activeAlarmsFromStorage();
      await _scheduler.rescheduleAll(alarms);
    } catch (e) {
      print('알람 재스케줄 실패: $e');
    }
  }

  // 저장된 알람 불러오기
  Future<List<MedicineAlarm>> getAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 사용자별 키 먼저, 없으면 레거시 키로 백필
      final alarmsString =
          prefs.getString(_alarmsKeyForUserStatic()) ??
          prefs.getString(_alarmsKeyLegacy);

      if (alarmsString == null) return [];

      final alarmsJson = json.decode(alarmsString) as List;
      return alarmsJson.map((json) => MedicineAlarm.fromJson(json)).toList();
    } catch (e) {
      print('알람 불러오기 실패: $e');
      return [];
    }
  }

  // 알람 삭제 (ID도 완전 삭제)
  Future<void> deleteAlarm(String alarmId) async {
    try {
      await _scheduler.cancel(alarmId);

      final prefs = await SharedPreferences.getInstance();
      final alarms = await getAlarms();
      alarms.removeWhere((a) => a.id == alarmId);

      final alarmsJson = alarms.map((a) => a.toJson()).toList();
      await prefs.setString(_alarmsKeyForUserStatic(), json.encode(alarmsJson));

      // 알람 삭제 시에는 알림 ID도 완전 삭제
      await prefs.remove(_notificationIdsKeyForStatic(alarmId));
      print('   🗑️ 알림 데이터 제거: scheduleId=$alarmId');
    } catch (e) {
      print('알람 삭제 실패: $e');
    }
  }

  // 알람 활성화/비활성화
  Future<void> toggleAlarm(String alarmId, bool isActive) async {
    try {
      final alarms = await getAlarms();
      final alarmIndex = alarms.indexWhere((a) => a.id == alarmId);

      if (alarmIndex >= 0) {
        final updatedAlarm = alarms[alarmIndex].copyWith(isActive: isActive);
        alarms[alarmIndex] = updatedAlarm;

        final prefs = await SharedPreferences.getInstance();
        final alarmsJson = alarms.map((a) => a.toJson()).toList();
        await prefs.setString(_alarmsKeyForUserStatic(), json.encode(alarmsJson));

        if (isActive) {
          await _scheduler.schedule(updatedAlarm);
        } else {
          await _scheduler.cancel(alarmId);
        }
      }
    } catch (e) {
      print('알람 상태 변경 실패: $e');
    }
  }

  // 전체화면 알림을 표시하는 메서드
  static void showFullscreenAlarm(
    BuildContext context,
    MedicineAlarm alarm,
    TimeOfDay time,
    String day, {
    int notificationId = 0,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenAlarmPage(
          alarm: alarm,
          time: time,
          day: day,
          notificationId: notificationId,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

/// iOS 로컬 알림 64개 예산 롤링 재예약(plan §7)과 AlarmKit 완료 기록 반영을
/// 앱 포그라운드 진입 때마다 트리거하는 전용 옵저버. `AlarmService.initialize()`
/// 에서만 등록하므로 다른 파일(app_shell.dart 등)을 건드리지 않는다.
class _AlarmServiceLifecycleObserver extends WidgetsBindingObserver {
  Future<void> Function()? onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed?.call();
    }
  }
}
