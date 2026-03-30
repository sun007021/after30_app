import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  static const bool _verboseLogs = false; // 상세 로그 스위치
  static const String actionKeySnooze10 = 'SNOOZE_10';
  static const String actionKeyCheckOthers = 'CHECK_OTHERS';

  static const String _alarmsKeyLegacy = 'medicine_alarms';
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

  // 10분 미루기(단발성 재알림)
  Future<void> snoozeNotification({
    required int baseNotificationId,
    required MedicineAlarm alarm,
    int minutes = 10,
  }) async {
    try {
      final snoozeId = _nextNotificationId++;
      final target = DateTime.now().add(Duration(minutes: minutes));
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: snoozeId,
          channelKey: 'medicine_alarms',
          title: '약 복용 알람 (미루기)',
          body: '${alarm.name} ${minutes}분 후 다시 알려드릴게요.',
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
                '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}',
            'day': _weekdayToKor(target.weekday),
            'notificationId': '$snoozeId',
            'fs': '1',
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: actionKeySnooze10,
            label: '복용 완료',
            actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(key: actionKeyCheckOthers, label: '이외 약 체크'),
        ],
        schedule: NotificationCalendar(
          year: target.year,
          month: target.month,
          day: target.day,
          hour: target.hour,
          minute: target.minute,
          second: 0,
          millisecond: 0,
          repeats: false,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
    } catch (e) {
      print('미루기 스케줄 실패: $e');
    }
  }

  static String _weekdayToKor(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final idx = (weekday - 1).clamp(0, 6);
    return days[idx];
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

  static Future<void> _markTakenBestEffort({
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
        return;
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
    } catch (e) {
      print('복용 완료 API 호출 실패: $e');
    }
  }

  // 외부(UI)에서 복용 완료를 호출할 수 있도록 공개 메서드 제공
  static Future<void> markTakenFromUi({
    required String medicineName,
    required String dayKor,
    required String hhmm,
  }) async {
    await _markTakenBestEffort(
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
      if (pressedKey == actionKeySnooze10) {
        // 복용 완료: 현재 알림만 닫고 종료
        try {
          await _markTakenBestEffort(
            medicineName: name,
            dayKor: day,
            hhmm: timeStr,
          );
          await AwesomeNotifications().cancel(notifId);
          print('복용 완료 처리됨: notificationId=$notifId');
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
      // 기본 동작(버튼 키 없음)은 아무 것도 하지 않음 - 자동 네비게이션 방지
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
              : _nextNotificationId++;

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
      final now = DateTime.now();
      final dayIndex = _getDayIndex(day);

      // 다음 해당 요일의 시간 계산
      var nextAlarmTime = _getNextAlarmTime(now, dayIndex, time);

      if (_verboseLogs) {
        print(
          '      📅 $day ${time.hour}:${time.minute} - 다음 알람: ${nextAlarmTime.toString()}',
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
            key: actionKeySnooze10,
            label: '복용 완료',
            actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(key: actionKeyCheckOthers, label: '이외 약 체크'),
        ],
        schedule: NotificationCalendar(
          year: nextAlarmTime.year,
          month: nextAlarmTime.month,
          day: nextAlarmTime.day,
          hour: nextAlarmTime.hour,
          minute: nextAlarmTime.minute,
          second: 0,
          millisecond: 0,
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

  DateTime _getNextAlarmTime(DateTime now, int targetDay, TimeOfDay time) {
    var nextAlarm = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // 요일 차이를 먼저 계산해 같은 주의 목표 요일로 이동
    var daysUntil = (targetDay - now.weekday + 7) % 7;
    nextAlarm = nextAlarm.add(Duration(days: daysUntil));

    // 목표 요일이 "오늘"인데 시간이 이미 지났거나 동일하면 다음 주로 이동
    if (daysUntil == 0 && !nextAlarm.isAfter(now)) {
      nextAlarm = nextAlarm.add(const Duration(days: 7));
    }

    return nextAlarm;
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
