import 'dart:io';

import 'package:flutter/services.dart';

import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';

/// iOS 알림 승인 상태(`UNAuthorizationStatus`).
enum NotificationAuthorizationStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,
}

NotificationAuthorizationStatus _parseNotificationAuthStatus(Object? raw) {
  switch (raw) {
    case 'authorized':
      return NotificationAuthorizationStatus.authorized;
    case 'denied':
      return NotificationAuthorizationStatus.denied;
    case 'provisional':
      return NotificationAuthorizationStatus.provisional;
    case 'ephemeral':
      return NotificationAuthorizationStatus.ephemeral;
    default:
      return NotificationAuthorizationStatus.notDetermined;
  }
}

/// 기기 알람/알림 권한·설정 화면 접근을 감싸는 어댑터(plan §6 W4 3항).
/// `my_page.dart`의 "디바이스 알람 허용" 설정 UI(W9)가 사용한다.
///
/// - Android: 기존 `after30/native` 네이티브 채널(`MainActivity.kt`)을
///   그대로 감싼다 — 동작 변화 없음.
/// - iOS: 알림 승인 상태, Time Sensitive 허용 여부, AlarmKit 권한 상태,
///   설정 앱(`app-settings:`) 열기를 제공한다.
class DeviceAlarmSettings {
  DeviceAlarmSettings._();

  static const MethodChannel _native = MethodChannel('after30/native');

  // ---------------------------------------------------------------------
  // Android(기존 네이티브 채널 그대로 감싼 것)
  // ---------------------------------------------------------------------

  static Future<bool> isDeviceLocked() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _native.invokeMethod<bool>('isDeviceLocked') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _native.invokeMethod<bool>('isExactAlarmAllowed') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _native.invokeMethod<bool>('openExactAlarmSettings');
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _native.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _native.invokeMethod<bool>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------

  static Future<NotificationAuthorizationStatus> notificationAuthorizationStatus() async {
    if (!Platform.isIOS) return NotificationAuthorizationStatus.notDetermined;
    try {
      final raw = await _native.invokeMethod<String>('notificationAuthorizationStatus');
      return _parseNotificationAuthStatus(raw);
    } catch (_) {
      return NotificationAuthorizationStatus.notDetermined;
    }
  }

  static Future<bool> isTimeSensitiveAllowed() async {
    if (!Platform.isIOS) return false;
    try {
      return await _native.invokeMethod<bool>('isTimeSensitiveAllowed') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<AlarmKitAuthorizationStatus> alarmKitAuthorizationStatus() async {
    if (!Platform.isIOS) return AlarmKitAuthorizationStatus.notSupported;
    final alarmKit = AlarmService.alarmKitScheduler;
    if (alarmKit == null) return AlarmKitAuthorizationStatus.notSupported;
    return alarmKit.authorizationStatus();
  }

  /// iOS 설정 앱(`app-settings:`)을 연다. Android는 배터리/정확한 알람
  /// 설정처럼 목적이 갈리므로 각 메서드를 그대로 쓴다.
  static Future<bool> openAppSettings() async {
    if (!Platform.isIOS) return false;
    try {
      return await _native.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
