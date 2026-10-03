import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/login_footer.dart';
import 'package:after30/features/login/ui/login_header.dart';
import 'package:after30/features/login/ui/signup_intro.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignupIntroPage', () {
    testWidgets('iOS: 캡슐 이메일 버튼이 약관 화면으로 이동한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(
        buildAuthApp(
          const SignupIntroPage(),
          TargetPlatform.iOS,
          routes: {'/signup-terms': (_) => const Scaffold(body: Text('약관 화면'))},
        ),
      );

      expect(find.text('간편하게 SNS로 가입하세요'), findsOneWidget);
      expect(find.text('카카오로 시작하기'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tap(find.widgetWithText(AppButton, '이메일로 가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('약관 화면'), findsOneWidget);
    });

    testWidgets('Android: 기존 파란 헤더와 사각 테두리 버튼 값 유지', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupIntroPage(), TargetPlatform.android));

      expect(find.byType(AppButton), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF235DFF));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final shape = button.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(button.style!.side!.resolve({})!.color, const Color(0xFF111111));
      expect(tester.getSize(find.byType(OutlinedButton)).height, 48);
    });
  });

  group('LoginHeader/LoginFooter', () {
    Future<TextStyle> styleOf(WidgetTester tester, TargetPlatform p, Widget w, String text) async {
      await tester.pumpWidget(buildAuthApp(Scaffold(body: w), p));
      return tester.widget<Text>(find.text(text)).style!;
    }

    testWidgets('Android는 기존 회색/크기를 유지한다', (tester) async {
      var s = await styleOf(tester, TargetPlatform.android, const LoginHeader(), '건강한 식습관을 위한 알림');
      expect(s.fontSize, 16);
      expect(s.color, Colors.grey);
      s = await styleOf(
        tester,
        TargetPlatform.android,
        const LoginFooter(),
        '시작하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
      );
      expect(s.fontSize, 12);
      expect(s.color, Colors.grey);
    });

    testWidgets('iOS는 토큰 보조 라벨 색을 쓴다', (tester) async {
      var s = await styleOf(tester, TargetPlatform.iOS, const LoginHeader(), '건강한 식습관을 위한 알림');
      expect(s.fontSize, 17);
      expect(s.color, AppColors.secondaryLabel);
      s = await styleOf(
        tester,
        TargetPlatform.iOS,
        const LoginFooter(),
        '시작하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
      );
      expect(s.fontSize, 13);
      expect(s.color, AppColors.secondaryLabel);
    });
  });
}
