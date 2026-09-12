import 'package:after30/features/onboarding/ui/onboarding_page.dart';
import 'package:flutter/material.dart';
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
}
