import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();
  static const bool _verboseLogs = false; // 상세 로그 스위치

  static const String _alarmsKey = 'medicine_alarms';
  static int _nextNotificationId = 1; // 순차적 알람 ID
  static GlobalKey<NavigatorState>? _navigatorKey; // 전체화면 네비게이션용

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
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
          channelShowBadge: true,
          enableVibration: true,
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
          category: NotificationCategory.Alarm,
          displayOnBackground: true,
          displayOnForeground: true,
          payload: {
            'alarmId': alarm.id,
            'medicineName': alarm.name,
            'time': '${target.hour}:${target.minute}',
            'day': _weekdayToKor(target.weekday),
            'notificationId': '$snoozeId',
          },
        ),
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

  @pragma('vm:entry-point')
  static Future<void> _onNotificationTapped(
    ReceivedAction receivedAction,
  ) async {
    // 알람 탭 시 전체화면 페이지로 이동
    try {
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

      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => FullscreenAlarmPage(
            alarm: alarm,
            time: TimeOfDay(hour: hour, minute: minute),
            day: day,
            notificationId: notifId,
          ),
          fullscreenDialog: true,
        ),
      );
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
    try {
      final payload = receivedNotification.payload ?? {};
      final alarmId = payload['alarmId'] ?? '';
      final name = payload['medicineName'] ?? '약';
      final timeStr = payload['time'] ?? '08:00';
      final day = payload['day'] ?? '월';
      final notifId = receivedNotification.id ?? 0;

      final hour = int.tryParse(timeStr.split(':').first) ?? 8;
      final minute = int.tryParse(timeStr.split(':').last) ?? 0;

      // 앱이 전경에 올라온 직후 Navigator가 준비될 시간을 주기 위해 지연
      Future.delayed(const Duration(milliseconds: 150), () {
        final state = _navigatorKey?.currentState;
        if (state != null) {
          state.push(
            MaterialPageRoute(
              builder: (_) => FullscreenAlarmPage(
                alarm: MedicineAlarm(
                  id: alarmId.isEmpty ? null : alarmId,
                  name: name,
                  times: [TimeOfDay(hour: hour, minute: minute)],
                  days: [day],
                ),
                time: TimeOfDay(hour: hour, minute: minute),
                day: day,
                notificationId: notifId,
              ),
              fullscreenDialog: true,
            ),
          );
        }
      });
    } catch (e) {
      print('표시 콜백 내 네비게이션 실패: $e');
    }
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
      final notificationIdsKey = 'notification_ids_$alarmId';
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
          category: NotificationCategory.Alarm,
          displayOnBackground: true,
          displayOnForeground: true,
          payload: {
            'alarmId': alarm.id,
            'medicineName': alarm.name,
            'time': '${time.hour}:${time.minute}',
            'day': day,
            'notificationId': '$notificationId',
          },
        ),
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

    // 오늘 이미 지난 시간이면 다음 주로
    if (nextAlarm.isBefore(now)) {
      nextAlarm = nextAlarm.add(const Duration(days: 7));
    }

    // 목표 요일까지 조정
    while (nextAlarm.weekday != targetDay) {
      nextAlarm = nextAlarm.add(const Duration(days: 1));
    }

    return nextAlarm;
  }

  // 알람 취소 (ID는 유지)
  Future<void> cancelAlarm(String alarmId) async {
    try {
      // 저장된 알림 ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final notificationIdsKey = 'notification_ids_$alarmId';
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
      final notificationIdsKey = 'notification_ids_${alarm.id}';
      await prefs.setStringList(
        notificationIdsKey,
        notificationIds.map((id) => id.toString()).toList(),
      );
      print(
        '   🔔 알림 저장: scheduleId=${alarm.id}, count=${notificationIds.length}',
      );

      final alarmsJson = alarms.map((a) => a.toJson()).toList();
      await prefs.setString(_alarmsKey, json.encode(alarmsJson));
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
      final alarmsString = prefs.getString(_alarmsKey);

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
      await prefs.setString(_alarmsKey, json.encode(alarmsJson));

      // 알람 삭제 시에는 알림 ID도 완전 삭제
      final notificationIdsKey = 'notification_ids_$alarmId';
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
        await prefs.setString(_alarmsKey, json.encode(alarmsJson));
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
