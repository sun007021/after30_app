import 'package:after30/features/onboarding/ui/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/core/design/design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('다음 버튼으로 온보딩 4페이지를 지나 로그인 화면으로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const OnboardingPage(),
          '/login': (_) => const Scaffold(body: Text('로그인 화면')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('약, 이제 식후30분에게\n맡기세요.'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('먹어야 할때, 딱 맞춰\n알려드릴게요.'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('잘 챙겼는지 한눈에\n확인하세요.'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('혼자가 아니라,\n가족이 함께 챙겨요.'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 화면'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  Widget themedApp(TargetPlatform platform) => MaterialApp(
    theme: AppTheme.build().copyWith(platform: platform),
    routes: {
      '/': (_) => const OnboardingPage(),
      '/login': (_) => const Scaffold(body: Text('로그인 화면')),
    },
  );

  testWidgets('iOS: 캡슐 CTA, 7pt 점 인디케이터, 마지막 페이지는 시작하기', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(themedApp(TargetPlatform.iOS));
    await tester.pumpAndSettle();

    expect(find.byType(AppButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    // 점 4개, 각 7x7
    final dots = find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 7,
    );
    expect(dots, findsNWidgets(4));
    // CTA는 홈 인디케이터 영역(34pt) 위에 있다.
    expect(tester.getBottomLeft(find.byType(AppButton)).dy, lessThanOrEqualTo(2622 / 3 - 34));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.text('다음'), findsNothing);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 화면'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('Android: 기존 사각 버튼(곡률 12)과 파란 점 값을 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(themedApp(TargetPlatform.android));
    await tester.pumpAndSettle();

    expect(find.byType(AppButton), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF1963FF));
    final shape = button.style!.shape!.resolve({}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(tester.getSize(find.byType(ElevatedButton)).height, 45);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: 온보딩은 알림 권한을 요청하지 않는다', (tester) async {
      final calls = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channels = [
        'awesome_notifications',
        'flutter.baseflow.com/permissions/methods',
        'plugins.flutter.io/firebase_messaging',
        'after30/native',
        'dexterous.com/flutter/local_notifications',
      ];
      for (final name in channels) {
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          calls.add('$name:${call.method}');
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(MethodChannel(name), null));
      }

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(themedApp(platform));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(platform == TargetPlatform.iOS ? '시작하기' : '다음'));
      await tester.pumpAndSettle();

      expect(find.text('로그인 화면'), findsOneWidget);
      expect(calls, isEmpty);
    });
  }

  // base(origin/feature/28/ios-release)에서 측정한 Android 1.0배 첫 슬라이드 배치.
  // 스크롤 래퍼를 추가해도 같은 위치여야 한다(base 구현과 4슬라이드 전체를 비교해 확인).
  final baseRects = {
    Size(420, 900): [
      Rect.fromLTRB(134.0, 256.1, 286.0, 455.1),
      Rect.fromLTRB(52.4, 487.1, 367.6, 551.1),
      Rect.fromLTRB(97.4, 560.1, 322.6, 596.1),
    ],
    Size(375, 667): [
      Rect.fromLTRB(115.3, 121.1, 259.7, 310.1),
      Rect.fromLTRB(38.0, 340.5, 337.0, 433.5),
      Rect.fromLTRB(80.4, 442.1, 294.6, 476.1),
    ],
  };
  for (final entry in baseRects.entries) {
    testWidgets('Android 1.0배 ${entry.key}: 첫 슬라이드 이미지/제목/설명 위치가 base와 같다', (tester) async {
      tester.view.physicalSize = entry.key * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedApp(TargetPlatform.android));
      await tester.pumpAndSettle();

      final elements = [
        find.byType(Image).evaluate().first,
        ...find.textContaining('\n').evaluate().take(2),
      ];
      final actual = [
        for (final e in elements)
          (e.renderObject! as RenderBox).localToGlobal(Offset.zero) & (e.renderObject! as RenderBox).size,
      ];
      expect(actual, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final r = entry.value[i];
        expect(actual[i].left, closeTo(r.left, 0.05));
        expect(actual[i].top, closeTo(r.top, 0.05));
        expect(actual[i].right, closeTo(r.right, 0.05));
        expect(actual[i].bottom, closeTo(r.bottom, 0.05));
      }
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: SE 폭(750x1334 dpr2) 글자 2.0배에서도 모든 슬라이드가 넘치지 않고 스크롤된다', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build().copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          routes: {
            '/': (_) => const OnboardingPage(),
            '/login': (_) => const Scaffold(body: Text('로그인 화면')),
          },
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(tester.takeException(), isNull, reason: '슬라이드 ${i + 1}');
        // 내용이 화면보다 크면 세로로 스크롤되어 맨 아래(설명 문구)까지 닿는다.
        final scrollable = find.descendant(of: find.byType(PageView), matching: find.byType(Scrollable));
        final vertical = tester.widgetList<Scrollable>(scrollable).where((s) => s.axisDirection == AxisDirection.down);
        expect(vertical, isNotEmpty);
        if (i < 3) {
          await tester.tap(find.byType(platform == TargetPlatform.iOS ? AppButton : ElevatedButton));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('iOS: 점 인디케이터는 "N페이지 중 M페이지" 시맨틱을 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedApp(TargetPlatform.iOS));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('4페이지 중 1페이지'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('4페이지 중 2페이지'), findsOneWidget);
    expect(find.bySemanticsLabel('4페이지 중 1페이지'), findsNothing);
    handle.dispose();
  });
}
