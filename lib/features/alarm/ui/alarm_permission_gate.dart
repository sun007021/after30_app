import 'package:flutter/widgets.dart';
import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_permission_flow.dart';

/// 약 등록 화면이 알림 권한 상태를 확인/요청할 때 쓰는 창구.
/// 실제 앱은 [SystemAlarmPermissionGate]를 쓰고, 테스트는 가짜를 주입한다.
abstract class AlarmPermissionGate {
  const AlarmPermissionGate();

  /// 현재 시스템 알림 권한 상태.
  Future<NotificationAuthorizationStatus> status();

  /// 사전 설명 알럿 → 시스템 권한 요청(→ iOS 26+ AlarmKit). 허용되면 true.
  Future<bool> requestWithRationale(BuildContext context);

  /// 알림 권한은 이미 허용된 상태에서 AlarmKit 권한만 아직 결정되지 않았다면
  /// 요청한다.
  Future<void> ensureAlarmKit();

  /// 설정 앱을 연다.
  Future<bool> openSettings();
}

class SystemAlarmPermissionGate extends AlarmPermissionGate {
  const SystemAlarmPermissionGate();

  @override
  Future<NotificationAuthorizationStatus> status() =>
      DeviceAlarmSettings.notificationAuthorizationStatus();

  @override
  Future<bool> requestWithRationale(BuildContext context) =>
      ReminderPermissionFlow.requestWithRationale(context);

  @override
  Future<void> ensureAlarmKit() async {
    final alarmKit = AlarmService.alarmKitScheduler;
    if (alarmKit == null) return;
    try {
      final status = await alarmKit.authorizationStatus();
      if (status == AlarmKitAuthorizationStatus.notDetermined) {
        await alarmKit.requestAuthorization();
      }
    } catch (_) {}
  }

  @override
  Future<bool> openSettings() => DeviceAlarmSettings.openAppSettings();
}
