import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';

/// 마이페이지가 보여주는 iOS 기기 알람 권한 상태 묶음.
class MyDeviceAlarmStatus {
  const MyDeviceAlarmStatus({
    required this.notification,
    required this.timeSensitiveAllowed,
    required this.alarmKit,
  });

  final NotificationAuthorizationStatus notification;
  final bool timeSensitiveAllowed;
  final AlarmKitAuthorizationStatus alarmKit;

  bool get notificationAllowed =>
      notification == NotificationAuthorizationStatus.authorized ||
      notification == NotificationAuthorizationStatus.provisional ||
      notification == NotificationAuthorizationStatus.ephemeral;

  bool get alarmKitAuthorized => alarmKit == AlarmKitAuthorizationStatus.authorized;

  /// 알람이 실제로 울릴 수 있는지. AlarmKit이 허용되면 스케줄러가 AlarmKit
  /// 전략을 고르므로 알림 권한과 상관없이 울린다(`ReminderSchedulerSelector`).
  bool get alarmsReady => alarmKitAuthorized || notificationAllowed;

  /// 사용자가 설정 앱에서 직접 바꿔야 풀리는 상태인지. 미결정은 앱이 시스템
  /// 권한 창을 띄울 수 있으므로 포함하지 않는다. AlarmKit이 허용돼 있으면
  /// 알람은 울리므로 설정 안내를 띄우지 않는다.
  bool get needsSettings =>
      !alarmKitAuthorized &&
      (notification == NotificationAuthorizationStatus.denied ||
      alarmKit == AlarmKitAuthorizationStatus.denied ||
      (notificationAllowed && !timeSensitiveAllowed));
}

/// [DeviceAlarmSettings](정적 API)를 마이페이지에서 주입 가능한 형태로 감싼
/// 얇은 어댑터. 위젯 테스트에서 이 클래스를 상속해 가짜로 바꾼다.
class MyDeviceAlarmGateway {
  const MyDeviceAlarmGateway();

  /// iOS 권한 상태 3종을 한 번에 읽는다(Android에서는 쓰지 않는다).
  Future<MyDeviceAlarmStatus> loadStatus() async {
    final notification = await DeviceAlarmSettings.notificationAuthorizationStatus();
    final timeSensitive = await DeviceAlarmSettings.isTimeSensitiveAllowed();
    final alarmKit = await DeviceAlarmSettings.alarmKitAuthorizationStatus();
    return MyDeviceAlarmStatus(
      notification: notification,
      timeSensitiveAllowed: timeSensitive,
      alarmKit: alarmKit,
    );
  }

  /// Android 기존 판정: 정확한 알람 허용 && 배터리 최적화 제외.
  Future<bool> isAndroidReady() async {
    final exactAllowed = await DeviceAlarmSettings.isExactAlarmAllowed();
    final batteryIgnored = await DeviceAlarmSettings.isIgnoringBatteryOptimizations();
    return exactAllowed && batteryIgnored;
  }

  Future<void> openExactAlarmSettings() => DeviceAlarmSettings.openExactAlarmSettings();

  Future<void> openBatteryOptimizationSettings() =>
      DeviceAlarmSettings.openBatteryOptimizationSettings();

  Future<bool> openAppSettings() => DeviceAlarmSettings.openAppSettings();
}
