import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `AwesomeNotificationsPlatform.instance`는 실행 중인 호스트 OS를 보고
  // 실제 채널 구현(MethodChannelAwesomeNotifications) 대신 아무 것도 하지
  // 않는 `AwesomeNotificationsEmpty`를 고른다(macOS에서 `flutter test`를
  // 돌리면 그렇게 된다) — 그러면 어떤 채널 메서드도 호출되지 않아 이 테스트가
  // cancel/dismiss 구분을 검증할 수 없다. `iOS`로 강제해 실제 채널
  // 구현을 쓰게 한다.
  AwesomeNotificationsPlatform.operatingSystem = 'ios';

  // 리뷰 B1 회귀 테스트: 알림을 닫을 때 반복 예약까지 취소해버리는
  // `cancel()`이 아니라 표시된 알림만 닫는 `dismiss()`를 써야 한다.
  // "이외 약 체크" 슬라이드는 네트워크 호출 없이 이 호출만 검증할 수 있어
  // 이쪽으로 테스트한다("복용 완료" 슬라이드도 성공 시 같은 호출을 한다).
  testWidgets('이외 약 체크 슬라이드는 dismiss만 호출하고 cancel은 호출하지 않는다', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('awesome_notifications'), (
          call,
        ) async {
          calls.add(call.method);
          return true;
        });

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (context) => const Scaffold(body: Text('home'))},
        home: FullscreenAlarmPage(
          alarm: MedicineAlarm(
            id: 'a1',
            name: '혈압약',
            times: const [TimeOfDay(hour: 8, minute: 0)],
            days: const ['월'],
          ),
          time: const TimeOfDay(hour: 8, minute: 0),
          day: '월',
          notificationId: 42,
        ),
      ),
    );

    // 두 번째(하단) 슬라이드 버튼이 "이외 약 체크"다.
    final knob = find.byType(GestureDetector).at(1);
    final gesture = await tester.startGesture(tester.getCenter(knob));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(35, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // awesome_notifications 채널 메서드 이름은 `dismissNotification` /
    // `cancelNotification`이다(definitions.dart).
    expect(calls, contains('dismissNotification'));
    expect(calls, isNot(contains('cancelNotification')));
    expect(find.text('home'), findsOneWidget);
  });
}
