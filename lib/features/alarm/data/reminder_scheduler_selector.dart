import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/awesome_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// 런타임에 선택된 전략(plan §6 W4 1항 "런타임 선택").
enum ReminderStrategy { android, iosAlarmKit, iosLocalNotification }

/// [ReminderScheduler] 두 구현(AlarmKit / 로컬 알림)을 감싸, 매 호출마다
/// "지금 어떤 전략을 써야 하는가"를 판단하고 실제로 위임한다.
///
/// - Android: 항상 [AwesomeReminderScheduler](기존 동작 그대로).
/// - iOS 26+이고 AlarmKit 권한이 허용됨: [AlarmKitReminderScheduler].
/// - 그 외 iOS(16~25, 또는 26+이지만 권한 미허용): [AwesomeReminderScheduler]
///   의 iOS 분기(로컬 알림 fallback).
///
/// 마지막으로 쓴 전략을 SharedPreferences에 저장해 두고, 이번에 고른
/// 전략이 지난번과 다르면 이전 전략의 예약을 전부 취소한다(plan §6 W4 3c
/// "전략을 바꾸면 다른 전략의 대기 항목을 취소해야 한다" — 이중 알람 방지).
class ReminderSchedulerSelector implements ReminderScheduler {
  ReminderSchedulerSelector({
    required AwesomeReminderScheduler local,
    AlarmKitReminderScheduler? alarmKit,
  }) : _local = local,
       _alarmKit = alarmKit ?? (Platform.isIOS ? AlarmKitReminderScheduler() : null);

  static const String _lastStrategyKey = 'reminder_last_strategy';

  final AwesomeReminderScheduler _local;
  final AlarmKitReminderScheduler? _alarmKit;

  AlarmKitReminderScheduler? get alarmKit => _alarmKit;
  AwesomeReminderScheduler get local => _local;

  Future<ReminderStrategy> currentStrategy() async {
    if (!Platform.isIOS) return ReminderStrategy.android;
    final alarmKit = _alarmKit;
    if (alarmKit == null) return ReminderStrategy.iosLocalNotification;
    final status = await alarmKit.authorizationStatus();
    if (status == AlarmKitAuthorizationStatus.authorized) {
      return ReminderStrategy.iosAlarmKit;
    }
    return ReminderStrategy.iosLocalNotification;
  }

  Future<ReminderScheduler> _resolve() async {
    final strategy = await currentStrategy();
    await _switchAwayFromPreviousIfNeeded(strategy);
    switch (strategy) {
      case ReminderStrategy.iosAlarmKit:
        return _alarmKit!;
      case ReminderStrategy.android:
      case ReminderStrategy.iosLocalNotification:
        return _local;
    }
  }

  Future<void> _switchAwayFromPreviousIfNeeded(ReminderStrategy strategy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastName = prefs.getString(_lastStrategyKey);
      final currentName = strategy.name;
      if (lastName != null && lastName != currentName) {
        // 전략이 바뀌었다 — 이전 전략이 등록해 둔 예약을 모두 취소해
        // 같은 알람이 두 경로로 동시에 울리지 않게 한다.
        if (lastName == ReminderStrategy.iosAlarmKit.name) {
          await _alarmKit?.cancelAll();
        } else if (lastName == ReminderStrategy.iosLocalNotification.name) {
          await _local.cancelAll();
        }
      }
      await prefs.setString(_lastStrategyKey, currentName);
    } catch (e) {
      print('알람 전략 전환 처리 실패: $e');
    }
  }

  @override
  Future<bool> schedule(MedicineAlarm alarm) async => (await _resolve()).schedule(alarm);

  @override
  Future<void> cancel(String alarmId) async => (await _resolve()).cancel(alarmId);

  @override
  Future<void> cancelAll() async {
    await _local.cancelAll();
    await _alarmKit?.cancelAll();
  }

  @override
  Future<void> rescheduleAll(List<MedicineAlarm> activeAlarms) async =>
      (await _resolve()).rescheduleAll(activeAlarms);

  @override
  Future<ReminderBudgetStatus> pendingBudget() async => (await _resolve()).pendingBudget();
}
