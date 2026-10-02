import Flutter
import Foundation
import UIKit
import UserNotifications

/// Android의 `after30/native` MethodChannel과 동일한 이름으로 등록하는 iOS 구현.
/// Android 전용 메서드(`isDeviceLocked` 등)는 W1이 만든 스텁 값을 유지하고,
/// `DeviceAlarmSettings`(W4, `lib/core/platform/device_alarm_settings.dart`)가
/// 쓰는 iOS 전용 메서드를 추가한다(plan §6 W4 3항).
enum NativeChannel {
  static let channelName = "after30/native"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      // Android 전용(스텁 유지) - 실제 구현은 MainActivity.kt
      case "isDeviceLocked":
        result(false)
      case "isExactAlarmAllowed":
        result(true)
      case "isIgnoringBatteryOptimizations":
        result(true)
      case "openExactAlarmSettings":
        result(false)
      case "openBatteryOptimizationSettings":
        result(false)

      // iOS 전용(DeviceAlarmSettings)
      case "notificationAuthorizationStatus":
        notificationAuthorizationStatus { status in
          result(status)
        }
      case "isTimeSensitiveAllowed":
        isTimeSensitiveAllowed { allowed in
          result(allowed)
        }
      case "openAppSettings":
        result(openAppSettings())

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `UNUserNotificationCenter`의 승인 상태를 문자열로 변환한다.
  /// (`notDetermined`/`denied`/`authorized`/`provisional`/`ephemeral`)
  private static func notificationAuthorizationStatus(completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let value: String
      switch settings.authorizationStatus {
      case .notDetermined: value = "notDetermined"
      case .denied: value = "denied"
      case .authorized: value = "authorized"
      case .provisional: value = "provisional"
      case .ephemeral: value = "ephemeral"
      @unknown default: value = "notDetermined"
      }
      DispatchQueue.main.async { completion(value) }
    }
  }

  /// Time Sensitive 알림 권한이 허용돼 있는지(iOS 15+, entitlement 필요).
  private static func isTimeSensitiveAllowed(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let allowed: Bool
      if #available(iOS 15.0, *) {
        allowed = settings.timeSensitiveSetting == .enabled
      } else {
        allowed = false
      }
      DispatchQueue.main.async { completion(allowed) }
    }
  }

  /// 앱 설정 화면(`app-settings:`)을 연다.
  private static func openAppSettings() -> Bool {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
    guard UIApplication.shared.canOpenURL(url) else { return false }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
