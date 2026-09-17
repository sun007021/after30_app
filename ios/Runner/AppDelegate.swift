import Flutter
import UIKit
import awesome_notifications
import shared_preferences_foundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // awesome_notifications 공식 iOS 가이드: 백그라운드 알림 액션에서 사용할 플러그인은
    // 별도로 등록해야 MissingPluginException을 피할 수 있다.
    // (복용 완료 액션 처리 시 SharedPreferences에 접근하므로 함께 등록)
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
      SwiftAwesomeNotificationsPlugin.register(
        with: registry.registrar(forPlugin: "AwesomeNotificationsPlugin")!)
      SharedPreferencesPlugin.register(
        with: registry.registrar(forPlugin: "SharedPreferencesPlugin")!)
    }

    if let controller = window?.rootViewController as? FlutterViewController,
      let registrar = controller.registrar(forPlugin: "NativeChannel")
    {
      NativeChannel.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
