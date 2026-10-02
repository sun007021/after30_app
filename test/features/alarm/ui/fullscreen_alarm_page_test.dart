import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 실제 채널 구현을 쓰게 해야 dismiss/cancel 호출을 관찰할 수 있다(b1 테스트와 동일).
  AwesomeNotificationsPlatform.operatingSystem = 'ios';

  late List<String> notificationCalls;
  late List<String> hapticCalls;

  setUp(() {
    notificationCalls = [];
    hapticCalls = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('awesome_notifications'), (call) async {
      notificationCalls.add(call.method);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticCalls.add('${call.arguments}');
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('awesome_notifications'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final alarm = MedicineAlarm(
    id: 'a1',
    name: '혈압약',
    times: const [TimeOfDay(hour: 8, minute: 0)],
    days: const ['월'],
  );

  Future<void> pumpPage(
    WidgetTester tester,
    TargetPlatform platform, {
    required Future<bool> Function({
      required String medicineName,
      required String dayKor,
      required String hhmm,
    }) markTaken,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routes: {'/home': (context) => const Scaffold(body: Text('home'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullscreenAlarmPage(
                    alarm: alarm,
                    time: const TimeOfDay(hour: 8, minute: 0),
                    day: '월',
                    notificationId: 42,
                    markTaken: markTaken,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> slide(WidgetTester tester, String label) async {
    final track = find.ancestor(of: find.text(label), matching: find.byType(LayoutBuilder)).first;
    final knob = find.descendant(of: track, matching: find.byType(GestureDetector)).first;
    final gesture = await tester.startGesture(tester.getCenter(knob));
    for (var i = 0; i < 24; i++) {
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  Future<bool> ok({required String medicineName, required String dayKor, required String hhmm}) async => true;
  Future<bool> fail({required String medicineName, required String dayKor, required String hhmm}) async => false;

  testWidgets('PopScope(canPop: false)로 뒤로 가기를 막는다', (tester) async {
    await pumpPage(tester, TargetPlatform.android, markTaken: ok);

    final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
    expect(popScope.canPop, isFalse);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'WillPopScope'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('혈압약'), findsOneWidget);
  });

  testWidgets('복용 완료 슬라이드는 dismiss만 호출하고 cancel은 호출하지 않는다', (tester) async {
    await pumpPage(tester, TargetPlatform.iOS, markTaken: ok);

    await slide(tester, '슬라이드하여 복용 완료');
    await tester.pumpAndSettle();

    expect(notificationCalls, contains('dismissNotification'));
    expect(notificationCalls, isNot(contains('cancelNotification')));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('iOS: 복용 완료 성공 시 success 햅틱을 재생한다', (tester) async {
    await pumpPage(tester, TargetPlatform.iOS, markTaken: ok);

    await slide(tester, '슬라이드하여 복용 완료');
    await tester.pumpAndSettle();
    expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
  });

  testWidgets('Android: 햅틱을 재생하지 않는다', (tester) async {
    await pumpPage(tester, TargetPlatform.android, markTaken: ok);

    await slide(tester, '슬라이드하여 복용 완료');
    await tester.pumpAndSettle();
    expect(hapticCalls, isEmpty);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('iOS: 서버 기록 실패 시 AppToast로 알리고 화면과 알림을 유지한다', (tester) async {
    await pumpPage(tester, TargetPlatform.iOS, markTaken: fail);

    await slide(tester, '슬라이드하여 복용 완료');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('복용 완료 처리에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
    expect(find.text('혈압약'), findsOneWidget);
    expect(notificationCalls, isEmpty);
    expect(hapticCalls, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Android: 서버 기록 실패 시 기존처럼 SnackBar로 알린다', (tester) async {
    await pumpPage(tester, TargetPlatform.android, markTaken: fail);

    await slide(tester, '슬라이드하여 복용 완료');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('복용 완료 처리에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
  });

  testWidgets('iOS 슬라이드 버튼은 캡슐 글래스, Android는 불투명 트랙', (tester) async {
    await pumpPage(tester, TargetPlatform.iOS, markTaken: ok);
    expect(find.byType(GlassSurface), findsNWidgets(2));
  });

  testWidgets('Android에는 글래스 표면이 없다', (tester) async {
    await pumpPage(tester, TargetPlatform.android, markTaken: ok);
    expect(find.byType(GlassSurface), findsNothing);
  });

  testWidgets('시계는 FittedBox 안에 있고 큰 글꼴(Dynamic Type)에서도 넘치지 않는다', (tester) async {
    await pumpPage(tester, TargetPlatform.iOS, markTaken: ok, textScale: 2.0);

    expect(
      find.ancestor(of: find.textContaining(':'), matching: find.byType(FittedBox)),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
