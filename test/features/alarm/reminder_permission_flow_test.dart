import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/reminder_permission_flow.dart';

/// `ReminderPermissionFlow`의 "로그인 후 1회만 요청" 게이팅을 검증한다.
///
/// 참고: `dart:io`의 `Platform.isIOS`/`isAndroid`는 `flutter test`를 실행하는
/// 호스트 OS(이 저장소 기준 macOS)를 그대로 보고하기 때문에, 단위 테스트
/// 환경에서는 둘 다 false다. 그래서 이 테스트는 플랫폼 분기 자체(Android
/// awesome_notifications 경로, iOS Firebase/AlarmKit 경로)가 아니라
/// SharedPreferences 플래그로 "1회만 요청"하는 로직을 검증한다. 실제 iOS
/// 권한 다이얼로그/AlarmKit 요청 결과는 실기기 체크리스트로 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const awesomeChannel = MethodChannel('awesome_notifications');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      awesomeChannel,
      (call) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      awesomeChannel,
      null,
    );
  });

  testWidgets('ensureRequestedAfterLogin은 최초 1회만 플래그를 세팅한다', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reminder_permission_requested_after_login'), isNot(true));

    await ReminderPermissionFlow.ensureRequestedAfterLogin(capturedContext);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reminder_permission_requested_after_login'), isTrue);

    // 두 번째 호출은 예외 없이 조용히 무시돼야 한다(이미 요청함).
    await ReminderPermissionFlow.ensureRequestedAfterLogin(capturedContext);
    expect(prefs.getBool('reminder_permission_requested_after_login'), isTrue);
  });

  testWidgets('requestWithRationale는 사전 설명을 취소하면 아무 것도 요청하지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => ReminderPermissionFlow.requestWithRationale(context),
              child: const Text('요청'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('요청'));
    await tester.pumpAndSettle();

    // 알럿의 취소 버튼("나중에")을 누른다.
    expect(find.text('나중에'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    // 취소했으므로 플래그/채널 호출 없이 조용히 끝나야 한다(예외가 없으면 통과).
  });
}
