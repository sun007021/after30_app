import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/email_login_page.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpAuthStorage);
  tearDown(tearDownAuthStorage);

  Future<void> fillIos(WidgetTester tester) async {
    await tester.enterText(find.byType(CupertinoTextField).first, 'a@b.com');
    await tester.enterText(find.byType(CupertinoTextField).last, 'pw');
    await tester.pump();
  }

  group('iOS', () {
    testWidgets('루트에 이 화면만 남은 경우(가입 직후)에는 눌러도 동작 없는 뒤로 버튼을 숨긴다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.back), findsNothing);
      expect(find.text('로그인'), findsWidgets);
    });

    testWidgets('가입 완료 이동(pushNamedAndRemoveUntil) 뒤에도 뒤로 버튼이 없다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(
        buildAuthApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/email-login', (_) => false),
              child: const Text('가입 완료'),
            ),
          ),
          TargetPlatform.iOS,
          routes: {'/email-login': (_) => const EmailLoginPage()},
        ),
      );
      await tester.tap(find.text('가입 완료'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailLoginPage), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.back), findsNothing);
    });

    testWidgets('다른 화면 위에 쌓인 경우에는 뒤로 버튼이 있고 눌러서 돌아간다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(
        buildAuthApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/email-login'),
              child: const Text('이메일 로그인'),
            ),
          ),
          TargetPlatform.iOS,
          routes: {'/email-login': (_) => const EmailLoginPage()},
        ),
      );
      await tester.tap(find.text('이메일 로그인'));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.back), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.back));
      await tester.pumpAndSettle();
      expect(find.byType(EmailLoginPage), findsNothing);
    });

    testWidgets('이메일/비밀번호 자동완성 힌트와 AutofillGroup이 설정된다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[0].autofillHints, [AutofillHints.email, AutofillHints.username]);
      expect(fields[0].textInputAction, TextInputAction.next);
      expect(fields[1].autofillHints, [AutofillHints.password]);
      expect(fields[1].textInputAction, TextInputAction.done);
      expect(fields[1].obscureText, isTrue);
    });

    testWidgets('이메일에서 다음을 누르면 비밀번호로 포커스가 이동한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      await tester.tap(find.byType(CupertinoTextField).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final password = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField).last);
      expect(password.focusNode!.hasFocus, isTrue);
    });

    testWidgets('눈 아이콘으로 비밀번호 표시를 전환한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      await tester.tap(find.byIcon(CupertinoIcons.eye_slash_fill));
      await tester.pump();
      final password = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField).last);
      expect(password.obscureText, isFalse);
    });

    testWidgets('실패하면 오류가 비밀번호 필드 아래에 인라인으로 표시된다', (tester) async {
      useIphoneViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 10));
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      await fillIos(tester);
      await tester.tap(find.widgetWithText(AppButton, '로그인'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('이메일 또는 비밀번호가 일치하지 않습니다.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('150ms 간격으로 두 번 탭해도 백엔드 호출은 한 번이다', (tester) async {
      useIphoneViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 500));
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      await fillIos(tester);
      final cta = find.byType(AppButton);
      await tester.tap(cta);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(cta, warnIfMissed: false);
      // 키보드 완료로 다시 제출해도 막힌다.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.calls.where((p) => p.contains('login')), hasLength(1));
    });

    testWidgets('키보드가 올라와도 CTA가 키보드 위에 보인다', (tester) async {
      useIphoneViewport(tester, keyboard: 336);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));
      await tester.pump();

      final ctaBottom = tester.getBottomLeft(find.byType(AppButton)).dy;
      final keyboardTop = 2622 / 3 - 336;
      expect(ctaBottom, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('키보드가 없을 때 CTA는 홈 인디케이터 영역(34pt) 위에 있다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.iOS));

      final ctaBottom = tester.getBottomLeft(find.byType(AppButton)).dy;
      expect(ctaBottom, lessThanOrEqualTo(2622 / 3 - 34));
    });
  });

  group('Android 기존 외형 유지', () {
    testWidgets('기존 입력창/버튼 값 그대로이고 AutofillGroup이 없다', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.android));

      expect(find.byType(AutofillGroup), findsNothing);
      expect(find.byType(CupertinoTextField), findsNothing);
      expect(find.byType(AppButton), findsNothing);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      expect(fields[0].keyboardType, TextInputType.emailAddress);
      expect(fields[0].decoration!.border, InputBorder.none);
      expect(fields[0].decoration!.hintText, '이메일 주소');
      expect(fields[0].decoration!.hintStyle!.color, const Color(0xFF9CA3AF));
      expect(fields[0].decoration!.hintStyle!.fontSize, 14);
      expect(fields[1].obscureText, isTrue);
      expect(fields[1].textInputAction, TextInputAction.done);

      // 입력창 컨테이너: 배경 F9F9F9, 테두리 111111 1px, 반지름 12
      final box = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == const Color(0xFFF9F9F9));
      expect(box.borderRadius, BorderRadius.circular(12));
      expect((box.border as Border).top.color, const Color(0xFF111111));
      expect((box.border as Border).top.width, 1);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = button.style!;
      expect(style.backgroundColor!.resolve({}), const Color(0xFF235DFF));
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFD3DEFF),
      );
      final shape = style.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(5));
      expect(tester.getSize(find.byType(ElevatedButton)), const Size(120, 30));
    });

    testWidgets('실패하면 SnackBar로 알린다', (tester) async {
      useAndroidViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 10));
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.android));

      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'pw');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('이메일 또는 비밀번호가 일치하지 않습니다.'), findsOneWidget);
    });

    testWidgets('150ms 간격으로 두 번 탭해도 백엔드 호출은 한 번이다', (tester) async {
      useAndroidViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 500));
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const EmailLoginPage(), TargetPlatform.android));

      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'pw');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.calls.where((p) => p.contains('login')), hasLength(1));
    });
  });
}
