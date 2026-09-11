import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';
import 'package:after30/features/my/settings_store.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  static const bool _verboseLogs = false; // 상세 로그 스위치
  // 문자열 값은 기기에 이미 예약된 알림의 액션 키와 호환되어야 하므로 유지하고,
  // 실제 동작(복용 완료)에 맞춰 식별자 이름만 정리했다.
  static const String actionKeyMarkTaken = 'SNOOZE_10';
  static const String actionKeyCheckOthers = 'CHECK_OTHERS';

  static const String _alarmsKeyLegacy = 'medicine_alarms';
  static const String _nextNotificationIdKey = 'alarm_next_notification_id';
  static const int _maxNotificationId = 2000000; // 32비트 정수 범위 내 안전 상한
  static String? _currentUserId; // 사용자 네임스페이스
  static int _nextNotificationId = 1; // 순차적 알람 ID
  static GlobalKey<NavigatorState>? _navigatorKey; // 전체화면 네비게이션용

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // 로그인/앱 시작 시 현재 사용자 설정
  static void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  String _alarmsKeyForUser() {
    return _currentUserId == null
        ? _alarmsKeyLegacy
        : 'medicine_alarms_${_currentUserId}';
  }

  String _notificationIdsKeyFor(String alarmId) {
    return _currentUserId == null
        ? 'notification_ids_$alarmId'
        : 'notification_ids_${_currentUserId}_$alarmId';
  }

  Future<void> initialize() async {
    // 시간대 초기화
    tz.initializeTimeZones();

    // 순차적 알람 ID 카운터 복원(앱 재시작 시 리셋되어 기존 알림을 덮어쓰는 문제 방지)
    await _restoreNextNotificationId();

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

    // 알림 권한 요청
    await AwesomeNotifications().requestPermissionToSendNotifications();

    // 알림 액션 리스너 설정
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: AlarmService._onNotificationTapped,
      onNotificationCreatedMethod: AlarmService._onNotificationCreated,
      onNotificationDisplayedMethod: AlarmService._onNotificationDisplayed,
      onDismissActionReceivedMethod: AlarmService._onDismissActionReceived,
    );
  }

  // 다음 발급할 알림 ID를 SharedPreferences에서 복원(없으면 기존 최댓값+1로 보정)
  Future<void> _restoreNextNotificationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_nextNotificationIdKey);
      if (stored != null && stored > 0) {
        _nextNotificationId = stored;
      }

      // 저장된 notification_ids_* 중 최댓값보다 작으면 최댓값+1로 보정(기존 사용자 마이그레이션)
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

  // 다음 알림 ID를 발급하고 영속화(상한 도달 시 1로 순환)
  Future<int> _allocateNextNotificationId() async {
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
      if (pressedKey == actionKeyMarkTaken) {
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
      } else if (pressedKey == actionKeyCheckOthers) {
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

      // 기존 알림 ID 가져오기 (수정 시 재사용)
      final existingNotificationIds = await _getExistingNotificationIds(
        alarm.id,
      );
      if (_verboseLogs) {
        print('   🔄 기존 알림 ID: $existingNotificationIds');
      }

      // 기존 알람 취소
      await cancelAlarm(alarm.id);
      if (_verboseLogs) {
        print('   ✅ 기존 알람 취소 완료');
      }

      final deviceAllowed = await MySettingsStore.getAllowDeviceNotifications();
      if (!deviceAllowed) {
        await _saveAlarmWithNotificationIds(alarm, []);
        print('   ⏸️ 디바이스 알람 비활성화 - 스케줄링 건너뜀');
        return true;
      }

      // 각 요일과 시간에 대해 알람 등록
      final notificationIds = <int>[];
      int idIndex = 0;

      for (final day in alarm.days) {
        for (final time in alarm.times) {
          if (_verboseLogs) {
            print('   📅 $day ${time.hour}:${time.minute} 알람 등록 중...');
          }

          // 기존 ID가 있으면 재사용, 없으면 새로 생성
          final notificationId = idIndex < existingNotificationIds.length
              ? existingNotificationIds[idIndex]
              : await _allocateNextNotificationId();

          await _scheduleSingleAlarmWithId(alarm, day, time, notificationId);
          notificationIds.add(notificationId);
          idIndex++;
        }
      }
      print('   ✅ 알람 스케줄링 완료: scheduleId=${alarm.id}');

      // 알람 저장 (알림 ID 포함)
      await _saveAlarmWithNotificationIds(alarm, notificationIds);
      print('   💾 알람 저장 완료');

      return true;
    } catch (e) {
      print('❌ 알람 스케줄링 실패: $e');
      return false;
    }
  }

  // 해당 알람이 이미 기기에 예약돼 있는지 확인(새 기기/재설치 후 동기화용)
  Future<bool> hasScheduledNotifications(String alarmId) async {
    final ids = await _getExistingNotificationIds(alarmId);
    return ids.isNotEmpty;
  }

  // 기존 알림 ID 가져오기
  Future<List<int>> _getExistingNotificationIds(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationIdsKey = _notificationIdsKeyFor(alarmId);
      final notificationIdsString = prefs.getStringList(notificationIdsKey);

      if (notificationIdsString != null) {
        return notificationIdsString.map((id) => int.parse(id)).toList();
      }
      return [];
    } catch (e) {
      print('기존 알림 ID 가져오기 실패: $e');
      return [];
    }
  }

  // ID를 지정해서 알람 등록
  Future<void> _scheduleSingleAlarmWithId(
    MedicineAlarm alarm,
    String day,
    TimeOfDay time,
    int notificationId,
  ) async {
    try {
      final dayIndex = _getDayIndex(day);

      if (_verboseLogs) {
        print(
          '      📅 $day ${time.hour}:${time.minute} - weekday=$dayIndex 매주 반복',
        );
        print('      🆔 알림ID: $notificationId (재사용됨)');
      }

      // 알람 스케줄링 (전체화면/웨이크업)
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
          payload: {
            'alarmId': alarm.id,
            'medicineName': alarm.name,
            'time':
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            'day': day,
            'notificationId': '$notificationId',
            'fs': '1',
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: actionKeyMarkTaken,
            label: '복용 완료',
            actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(key: actionKeyCheckOthers, label: '이외 약 체크'),
        ],
        schedule: NotificationCalendar(
          weekday: dayIndex,
          hour: time.hour,
          minute: time.minute,
          second: 0,
          repeats: true,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
      if (_verboseLogs) {
        print('      ✅ 단일 알람 스케줄링 완료');
      }
    } catch (e) {
      print('      ❌ 단일 알람 스케줄링 실패: $e');
      rethrow;
    }
  }

  int _getDayIndex(String day) {
    const dayMap = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
    return dayMap[day] ?? 1;
  }

  // 알람 취소 (ID는 유지)
  Future<void> cancelAlarm(String alarmId) async {
    try {
      // 저장된 알림 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final notificationIdsKey = _notificationIdsKeyFor(alarmId);
      final notificationIdsString = prefs.getStringList(notificationIdsKey);

      if (notificationIdsString != null) {
        for (final idString in notificationIdsString) {
          final notificationId = int.parse(idString);
          await AwesomeNotifications().cancel(notificationId);
          if (_verboseLogs) {
            print('   🔔 알림 취소: $notificationId');
          }
        }
        print('   ✅ 알림 취소 완료: scheduleId=$alarmId');
      }
    } catch (e) {
      print('알람 취소 실패: $e');
    }
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

  // 모든 알람 취소
  Future<void> cancelAllAlarms() async {
    await AwesomeNotifications().cancelAll();
  }

  // 모든 예약(스케줄)만 취소
  Future<void> cancelAllAlarmSchedules() async {
    await AwesomeNotifications().cancelAllSchedules();
  }

  // 모든 알람 데이터(스케줄 + 저장소) 정리
  Future<void> clearAllAlarmData() async {
    try {
      // 표시/대기 중인 모든 알림 및 모든 예약 스케줄 취소
      await cancelAllAlarms();
      await cancelAllAlarmSchedules();
      // 저장된 알람 목록 및 각 알림 ID 키 제거
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
      final alarms = await getAlarms();
      for (final alarm in alarms) {
        if (alarm.isActive) {
          await scheduleAlarm(alarm);
        }
      }
    } catch (e) {
      print('알람 재스케줄 실패: $e');
    }
  }

  // 알람 저장 (알림 ID 포함)
  Future<void> _saveAlarmWithNotificationIds(
    MedicineAlarm alarm,
    List<int> notificationIds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarms = await getAlarms();

      // 기존 알람이 있으면 업데이트, 없으면 추가
      final existingIndex = alarms.indexWhere((a) => a.id == alarm.id);
      if (existingIndex >= 0) {
        alarms[existingIndex] = alarm;
      } else {
        alarms.add(alarm);
      }

      // 알림 ID 저장
      final notificationIdsKey = _notificationIdsKeyFor(alarm.id);
      await prefs.setStringList(
        notificationIdsKey,
        notificationIds.map((id) => id.toString()).toList(),
      );
      print(
        '   🔔 알림 저장: scheduleId=${alarm.id}, count=${notificationIds.length}',
      );

      final alarmsJson = alarms.map((a) => a.toJson()).toList();
      await prefs.setString(_alarmsKeyForUser(), json.encode(alarmsJson));
      if (_verboseLogs) {
        print('   ✅ SharedPreferences 저장 완료');
      }
    } catch (e) {
      print('❌ 알람 저장 실패: $e');
      rethrow;
    }
  }

  // (미사용) 과거 저장 함수 제거됨

  // 저장된 알람 불러오기
  Future<List<MedicineAlarm>> getAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 사용자별 키 먼저, 없으면 레거시 키로 백필
      final alarmsString =
          prefs.getString(_alarmsKeyForUser()) ??
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
      await cancelAlarm(alarmId);

      final prefs = await SharedPreferences.getInstance();
      final alarms = await getAlarms();
      alarms.removeWhere((a) => a.id == alarmId);

      final alarmsJson = alarms.map((a) => a.toJson()).toList();
      await prefs.setString(_alarmsKeyForUser(), json.encode(alarmsJson));

      // 알람 삭제 시에는 알림 ID도 완전 삭제
      final notificationIdsKey = _notificationIdsKeyFor(alarmId);
      await prefs.remove(notificationIdsKey);
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

        if (isActive) {
          await scheduleAlarm(updatedAlarm);
        } else {
          await cancelAlarm(alarmId);
        }

        final prefs = await SharedPreferences.getInstance();
        final alarmsJson = alarms.map((a) => a.toJson()).toList();
        await prefs.setString(_alarmsKeyForUser(), json.encode(alarmsJson));
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
