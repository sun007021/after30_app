import 'package:flutter_test/flutter_test.dart';

import 'package:after30/core/platform/device_alarm_settings.dart';

/// 이 저장소의 단위 테스트는 호스트 OS(macOS)에서 돌아가므로
/// `Platform.isAndroid`/`isIOS`가 둘 다 false다(다른 알람 테스트 파일 참고).
/// 그래서 여기서는 "지원하지 않는 플랫폼(host)에서는 안전한 기본값을
/// 반환하고 예외를 던지지 않는다"만 검증한다. Android/iOS 채널 왕복 자체는
/// 실기기/시뮬레이터 체크리스트로 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android 전용 메서드는 호스트(비-Android)에서 안전한 기본값을 반환한다', () async {
    expect(await DeviceAlarmSettings.isDeviceLocked(), isFalse);
    expect(await DeviceAlarmSettings.isExactAlarmAllowed(), isTrue);
    expect(await DeviceAlarmSettings.isIgnoringBatteryOptimizations(), isTrue);
    await DeviceAlarmSettings.openExactAlarmSettings();
    await DeviceAlarmSettings.openBatteryOptimizationSettings();
  });

  test('iOS 전용 메서드는 호스트(비-iOS)에서 안전한 기본값을 반환한다', () async {
    expect(
      await DeviceAlarmSettings.notificationAuthorizationStatus(),
      NotificationAuthorizationStatus.notDetermined,
    );
    expect(await DeviceAlarmSettings.isTimeSensitiveAllowed(), isFalse);
    expect(await DeviceAlarmSettings.openAppSettings(), isFalse);
  });
}
