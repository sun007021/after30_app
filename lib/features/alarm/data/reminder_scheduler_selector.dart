import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
/// 전략이 지난번과 다르면 이전 전략의 예약을 전부 취소하고(plan §6 W4 3c)
/// 저장된 활성 알람 전체를 새 전략으로 다시 등록한다(리뷰 M6 — 바뀐 알람
/// 하나만이 아니라 전부를 새 전략으로 옮긴다).
///
/// 모든 공개 메서드는 하나의 async 체인으로 직렬화된다(리뷰 M3) — iOS
/// 로컬 알림의 전체 재계산과 AlarmKit의 "읽기→스케줄→저장"이 서로 겹쳐
/// 실행되며 생기는 경쟁 상태(추적되지 않는 예약, 중복 UUID)를 막는다.
class ReminderSchedulerSelector implements ReminderScheduler {
  ReminderSchedulerSelector({
    required AwesomeReminderScheduler local,
    AlarmKitReminderScheduler? alarmKit,
    this.activeAlarmsProvider,
    @visibleForTesting bool? forceIOS,
  }) : _local = local,
       _isIOS = forceIOS ?? Platform.isIOS,
       _alarmKit =
           alarmKit ?? ((forceIOS ?? Platform.isIOS) ? AlarmKitReminderScheduler() : null);

  static const String _lastStrategyKey = 'reminder_last_strategy';

  final AwesomeReminderScheduler _local;
  final AlarmKitReminderScheduler? _alarmKit;

  /// 실제로는 `Platform.isIOS`를 쓰지만, `dart:io`의 `Platform`은 단위
  /// 테스트에서 항상 호스트 OS를 보고하기 때문에(예: macOS에서
  /// `flutter test`를 돌리면 iOS도 Android도 아니다) 테스트에서만
  /// [forceIOS]로 덮어쓸 수 있게 열어 둔다.
  final bool _isIOS;

  /// 저장소 기준 활성 알람 전체를 읽어오는 콜백. 전략이 바뀔 때 그
  /// 전체를 새 전략으로 재등록하는 데 쓴다(M6). `AlarmService`가
  /// 생성 이후 지정한다(순환 의존 방지).
  Future<List<MedicineAlarm>> Function()? activeAlarmsProvider;

  /// 모든 공개 메서드 호출을 하나의 체인으로 직렬화한다(M3).
  Future<void> _chain = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  AlarmKitReminderScheduler? get alarmKit => _alarmKit;
  AwesomeReminderScheduler get local => _local;

  Future<ReminderStrategy> currentStrategy() async {
    if (!_isIOS) return ReminderStrategy.android;
    final alarmKit = _alarmKit;
    if (alarmKit == null) return ReminderStrategy.iosLocalNotification;
    final status = await alarmKit.authorizationStatus();
    if (status == AlarmKitAuthorizationStatus.authorized) {
      return ReminderStrategy.iosAlarmKit;
    }
    return ReminderStrategy.iosLocalNotification;
  }

  ReminderScheduler _resolveFor(ReminderStrategy strategy) {
    switch (strategy) {
      case ReminderStrategy.iosAlarmKit:
        return _alarmKit!;
      case ReminderStrategy.android:
      case ReminderStrategy.iosLocalNotification:
        return _local;
    }
  }

  /// 전략이 바뀌었으면 이전 전략의 예약을 전부 취소하고, 저장된 활성
  /// 알람 전체를 새 전략으로 다시 등록한다(M6). 호출부는 이미 `_serialized`
  /// 안에서 실행 중이라고 가정한다(직접 호출 금지).
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
        // 취소만 하고 끝내면 이번 호출이 다루는 알람 하나만 새 전략으로
        // 옮겨지고 나머지는 통째로 빠진다 — 저장된 활성 알람 전체를 새
        // 전략으로 다시 등록한다.
        final provider = activeAlarmsProvider;
        if (provider != null) {
          final allActive = await provider();
          await _resolveFor(strategy).rescheduleAll(allActive);
        }
      }
      await prefs.setString(_lastStrategyKey, currentName);
    } catch (e) {
      print('알람 전략 전환 처리 실패: $e');
    }
  }

  @override
  Future<bool> schedule(MedicineAlarm alarm) {
    return _serialized(() async {
      final strategy = await currentStrategy();
      await _switchAwayFromPreviousIfNeeded(strategy);
      return _resolveFor(strategy).schedule(alarm);
    });
  }

  @override
  Future<void> cancel(String alarmId) {
    return _serialized(() async {
      final strategy = await currentStrategy();
      await _switchAwayFromPreviousIfNeeded(strategy);
      await _resolveFor(strategy).cancel(alarmId);
    });
  }

  @override
  Future<void> cancelAll() {
    return _serialized(() async {
      await _local.cancelAll();
      await _alarmKit?.cancelAll();
    });
  }

  @override
  Future<void> rescheduleAll(List<MedicineAlarm> activeAlarms) {
    return _serialized(() async {
      final strategy = await currentStrategy();
      await _switchAwayFromPreviousIfNeeded(strategy);
      await _resolveFor(strategy).rescheduleAll(activeAlarms);
    });
  }

  @override
  Future<ReminderBudgetStatus> pendingBudget() {
    return _serialized(() async {
      final strategy = await currentStrategy();
      return _resolveFor(strategy).pendingBudget();
    });
  }
}
