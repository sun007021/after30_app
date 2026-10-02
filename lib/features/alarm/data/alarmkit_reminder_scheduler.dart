import 'package:flutter/services.dart';

import 'package:after30/features/alarm/data/reminder_scheduler.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// iOS 26+ AlarmKit 권한 상태(`AlarmManager.AuthorizationState` + iOS<26를
/// 나타내는 [notSupported]).
enum AlarmKitAuthorizationStatus { notSupported, notDetermined, denied, authorized }

AlarmKitAuthorizationStatus _parseAuthStatus(Object? raw) {
  switch (raw) {
    case 'authorized':
      return AlarmKitAuthorizationStatus.authorized;
    case 'denied':
      return AlarmKitAuthorizationStatus.denied;
    case 'notDetermined':
      return AlarmKitAuthorizationStatus.notDetermined;
    default:
      return AlarmKitAuthorizationStatus.notSupported;
  }
}

/// iOS 26+ AlarmKit 기반 스케줄러(plan §6 W4 3항). Swift 쪽
/// `ios/Runner/Alarm/AlarmKitBridge.swift`와 `after30/alarmkit`
/// MethodChannel로 통신한다.
///
/// AlarmKit은 OS가 직접 관리하는 알람이라 iOS 로컬 알림의 64개 대기 한도가
/// 없다(plan §7) — 그래서 [pendingBudget]은 항상
/// [ReminderBudgetStatus.unlimited]를 반환한다.
class AlarmKitReminderScheduler implements ReminderScheduler {
  AlarmKitReminderScheduler({
    MethodChannel? channel,
    Future<bool> Function()? deviceNotificationsAllowed,
  }) : _channel = channel ?? const MethodChannel('after30/alarmkit'),
       _deviceNotificationsAllowed = deviceNotificationsAllowed ?? (() async => true);

  final MethodChannel _channel;

  /// 사용자가 "디바이스 알람"을 꺼뒀는지(리뷰 M5 — AlarmKit도 로컬 알림과
  /// 동일하게 이 설정을 존중해야 한다. 그렇지 않으면 다음 앱 포그라운드
  /// 진입 때 재등록돼 버린다).
  final Future<bool> Function() _deviceNotificationsAllowed;

  Future<AlarmKitAuthorizationStatus> authorizationStatus() async {
    try {
      final raw = await _channel.invokeMethod<String>('authorizationStatus');
      return _parseAuthStatus(raw);
    } catch (_) {
      return AlarmKitAuthorizationStatus.notSupported;
    }
  }

  Future<AlarmKitAuthorizationStatus> requestAuthorization() async {
    try {
      final raw = await _channel.invokeMethod<String>('requestAuthorization');
      return _parseAuthStatus(raw);
    } catch (_) {
      return AlarmKitAuthorizationStatus.notSupported;
    }
  }

  @override
  Future<bool> schedule(MedicineAlarm alarm) async {
    if (!alarm.isActive || alarm.times.isEmpty || alarm.days.isEmpty) {
      await cancel(alarm.id);
      return true;
    }
    final allowed = await _deviceNotificationsAllowed();
    if (!allowed) {
      await cancel(alarm.id);
      return true;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('schedule', {
        'scheduleId': alarm.id,
        'medicineName': alarm.name,
        'days': alarm.days.map(_koreanDayToIso).toList(),
        'times': alarm.times
            .map((t) => {'hour': t.hour, 'minute': t.minute})
            .toList(),
      });
      return ok ?? false;
    } catch (e) {
      print('AlarmKit 스케줄링 실패: $e');
      return false;
    }
  }

  @override
  Future<void> cancel(String alarmId) async {
    try {
      await _channel.invokeMethod<bool>('cancel', {'scheduleId': alarmId});
    } catch (e) {
      print('AlarmKit 취소 실패: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod<bool>('cancelAll');
    } catch (e) {
      print('AlarmKit 전체 취소 실패: $e');
    }
  }

  @override
  Future<void> rescheduleAll(List<MedicineAlarm> activeAlarms) async {
    for (final alarm in activeAlarms) {
      await schedule(alarm);
    }
  }

  @override
  Future<ReminderBudgetStatus> pendingBudget() async => ReminderBudgetStatus.unlimited;

  /// 현재 AlarmKit에 등록된 모든 알람의 요약 정보(디버그/동기화 확인용).
  Future<List<Map<String, Object?>>> list() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list');
      if (raw == null) return const [];
      return raw.map((m) => m.cast<String, Object?>()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 지금 울리고 있는 AlarmKit 알람 정보(알림 본문 탭/콜드 스타트 라우팅용).
  /// 없으면 null.
  Future<Map<String, Object?>?> alertingAlarm() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('alertingAlarm');
      return raw;
    } catch (_) {
      return null;
    }
  }

  /// 백그라운드 "복용 완료" 인텐트가 기록해 둔 완료 항목을 읽기만 한다
  /// (지우지 않음 — 리뷰 M8). 각 항목을 처리한 뒤 성공한 것만
  /// [ackCompletion]으로 지운다.
  Future<List<Map<String, Object?>>> peekCompletions() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('peekCompletions');
      if (raw == null) return const [];
      return raw.map((m) => m.cast<String, Object?>()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// [peekCompletions]로 읽은 완료 항목 중 서버 반영에 성공한 것만
  /// 지운다. 실패하면(오프라인 등) 다음 폴링에서 다시 시도할 수 있도록
  /// 기록을 남겨 둔다(리뷰 M8).
  Future<bool> ackCompletion(String id) async {
    try {
      final ok = await _channel.invokeMethod<bool>('ackCompletion', {'id': id});
      return ok ?? false;
    } catch (e) {
      print('AlarmKit 완료 기록 확인 실패: $e');
      return false;
    }
  }

  static String _koreanDayToIso(String dayKor) {
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
}
