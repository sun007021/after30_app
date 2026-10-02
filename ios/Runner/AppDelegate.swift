import Flutter
import UIKit
import awesome_notifications
import flutter_secure_storage
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
    // 리뷰 M9: "복용 완료" 백그라운드 액션이 서버에 기록하려면
    // ApiClient의 인증 인터셉터가 TokenStore(Keychain, flutter_secure_storage
    // 기반)에서 액세스 토큰을 읽어야 한다 — 이 플러그인도 등록해 두지
    // 않으면 백그라운드 isolate에서 MissingPluginException이 나서 인증
    // 헤더 없이 요청이 나가거나 실패한다.
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
      SwiftAwesomeNotificationsPlugin.register(
        with: registry.registrar(forPlugin: "AwesomeNotificationsPlugin")!)
      SharedPreferencesPlugin.register(
        with: registry.registrar(forPlugin: "SharedPreferencesPlugin")!)
      FlutterSecureStoragePlugin.register(
        with: registry.registrar(forPlugin: "FlutterSecureStoragePlugin")!)
    }

    if let controller = window?.rootViewController as? FlutterViewController,
      let registrar = controller.registrar(forPlugin: "NativeChannel")
    {
      NativeChannel.register(with: registrar)
    } else {
      assertionFailure("NativeChannel 등록 실패: FlutterViewController 또는 registrar를 찾을 수 없음")
    }

    // iOS 26+ AlarmKit 브리지(W4). iOS 16~25에서는 채널 메서드가
    // "notSupported"류 응답만 반환하고 실제로는 아무 것도 하지 않는다.
    if let controller = window?.rootViewController as? FlutterViewController,
      let registrar = controller.registrar(forPlugin: "AlarmKitBridge")
    {
      AlarmKitBridge.register(with: registrar)
    } else {
      assertionFailure("AlarmKitBridge 등록 실패: FlutterViewController 또는 registrar를 찾을 수 없음")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
