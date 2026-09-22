import Flutter
import Foundation

/// Android의 `after30/native` MethodChannel과 동일한 이름으로 등록하는 iOS 스텁.
/// 알람 권한/설정 관련 실제 구현은 W4(iOS 알림/알람 엔진)에서 확장한다.
enum NativeChannel {
  static let channelName = "after30/native"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
