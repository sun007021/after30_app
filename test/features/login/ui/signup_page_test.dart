import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/signup_page.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpAuthStorage);
  tearDown(tearDownAuthStorage);

  Finder iosField(int i) => find.byType(CupertinoTextField).at(i);

  Future<void> fillIos(WidgetTester tester) async {
    await tester.enterText(iosField(0), '홍길동');
    await tester.enterText(iosField(1), 'a@b.com');
    await tester.enterText(iosField(2), 'password1');
    await tester.enterText(iosField(3), 'password1');
    await tester.tap(find.text('남'));
    await tester.pump();
  }

  group('iOS', () {
    testWidgets('자동완성 힌트와 포커스 순서(next, next, next, done)', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));

      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields = tester
          .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
          .toList();
      expect(fields, hasLength(4));
      expect(fields[0].autofillHints, [AutofillHints.name]);
      expect(fields[1].autofillHints, [AutofillHints.email, AutofillHints.username]);
      expect(fields[2].autofillHints, [AutofillHints.newPassword]);
      expect(fields[3].autofillHints, [AutofillHints.newPassword]);
      expect(fields.map((f) => f.textInputAction), [
        TextInputAction.next,
        TextInputAction.next,
        TextInputAction.next,
        TextInputAction.done,
      ]);

      // 이름 → 이메일 → 비밀번호 → 확인으로 포커스가 차례로 이동한다.
      await tester.tap(iosField(0));
      await tester.pump();
      for (var i = 1; i <= 3; i++) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        final next = tester.widget<CupertinoTextField>(iosField(i));
        expect(next.focusNode!.hasFocus, isTrue, reason: '$i번 필드 포커스');
      }
    });

    testWidgets('성별은 세그먼트 컨트롤이며 Dropdown은 없다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));

      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsOneWidget);
      var control = tester.widget<CupertinoSlidingSegmentedControl<String>>(
        find.byType(CupertinoSlidingSegmentedControl<String>),
      );
      expect(control.groupValue, isNull);

      await tester.tap(find.text('여'));
      await tester.pump();
      control = tester.widget<CupertinoSlidingSegmentedControl<String>>(
        find.byType(CupertinoSlidingSegmentedControl<String>),
      );
      expect(control.groupValue, '여');
    });

    testWidgets('비밀번호 규칙 안내와 인라인 검증 메시지', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));

      expect(find.text('8자 이상으로 입력해주세요'), findsOneWidget);

      await tester.enterText(iosField(2), 'short');
      await tester.pump();
      expect(find.text('비밀번호는 최소 8자 이상이어야 합니다'), findsOneWidget);
      expect(find.text('8자 이상으로 입력해주세요'), findsNothing);

      await tester.enterText(iosField(2), 'password1');
      await tester.enterText(iosField(3), 'password2');
      await tester.pump();
      expect(find.text('비밀번호가 일치하지 않습니다'), findsOneWidget);
    });

    testWidgets('모든 값이 유효해야 CTA가 활성화된다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));

      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
      await fillIos(tester);
      expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNotNull);
    });

    testWidgets('150ms 간격으로 두 번 탭해도 백엔드 호출은 한 번이다', (tester) async {
      useIphoneViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 500), statusCode: 409);
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));

      await fillIos(tester);
      await tester.tap(find.byType(AppButton));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.calls.where((p) => p.contains('register')), hasLength(1));
      // 토스트 타이머 정리
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('키보드가 올라와도 CTA가 키보드 위에 보인다', (tester) async {
      useIphoneViewport(tester, keyboard: 336);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));
      await tester.pump();

      final ctaBottom = tester.getBottomLeft(find.byType(AppButton)).dy;
      expect(ctaBottom, lessThanOrEqualTo(2622 / 3 - 336));
    });
  });

  group('Android 기존 외형 유지', () {
    testWidgets('Dropdown 성별, 기존 입력 장식 값, 버튼 값', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.android));

      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsNothing);
      expect(find.byType(AutofillGroup), findsNothing);
      expect(find.byType(AppButton), findsNothing);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(4));
      expect(fields[0].decoration!.hintText, '이름을 입력하세요');
      expect(fields[0].decoration!.border, InputBorder.none);
      expect(fields[0].decoration!.hintStyle!.color, const Color(0xFF9CA3AF));
      expect(fields[2].decoration!.hintText, '비밀번호를 8자 이상 입력하세요');
      expect(fields[2].textInputAction, TextInputAction.next);
      expect(fields[3].textInputAction, TextInputAction.done);

      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.dropdownColor, Colors.white);
      expect(dropdown.isExpanded, isTrue);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF235DFF));
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFD3DEFF),
      );
      expect(tester.getSize(find.byType(ElevatedButton)), const Size(120, 30));
    });

    testWidgets('드롭다운으로 성별을 고르고 등록 버튼이 활성화된다', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.android));

      final texts = find.byType(TextField);
      await tester.enterText(texts.at(0), '홍길동');
      await tester.enterText(texts.at(1), 'a@b.com');
      await tester.enterText(texts.at(2), 'password1');
      await tester.enterText(texts.at(3), 'password1');
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('여').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('150ms 간격으로 두 번 탭해도 백엔드 호출은 한 번이다', (tester) async {
      useAndroidViewport(tester);
      final backend = FakeBackend(delay: const Duration(milliseconds: 500), statusCode: 409);
      backend.install();
      addTearDown(backend.uninstall);
      await tester.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.android));

      final texts = find.byType(TextField);
      await tester.enterText(texts.at(0), '홍길동');
      await tester.enterText(texts.at(1), 'a@b.com');
      await tester.enterText(texts.at(2), 'password1');
      await tester.enterText(texts.at(3), 'password1');
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('남').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.calls.where((p) => p.contains('register')), hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
