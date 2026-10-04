import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/features/login/ui/kakao_login_button.dart';
import 'package:after30/features/login/ui/login.dart';

import 'auth_test_support.dart';

/// signIn을 [delay]만큼 지연시키고 호출 횟수를 세는 가짜 클라이언트.
class _SlowCancelClient implements AuthProviderClient {
  _SlowCancelClient(this.delay);

  final Duration delay;
  int calls = 0;

  @override
  String get providerId => 'fake';

  @override
  Future<AuthSignInResult?> signIn() async {
    calls++;
    await Future<void>.delayed(delay);
    return null; // 사용자 취소
  }
}

/// 사용자가 카카오톡에서 승인/취소 없이 돌아온 상황: signIn이 끝나지 않는다.
class _NeverCompletingClient implements AuthProviderClient {
  int calls = 0;
  @override
  String get providerId => 'fake';
  @override
  Future<AuthSignInResult?> signIn() {
    calls++;
    return Completer<AuthSignInResult?>().future;
  }
}

class _ThrowingClient implements AuthProviderClient {
  int calls = 0;

  @override
  String get providerId => 'fake';

  @override
  Future<AuthSignInResult?> signIn() async {
    calls++;
    throw StateError('boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child, TargetPlatform p) =>
      buildAuthApp(Scaffold(body: Center(child: child)), p);

  group('KakaoLoginButton', () {
    testWidgets('iOS: 높이 50 캡슐, #FEE500, 아이콘+텍스트, 탭 시 콜백', (tester) async {
      useIphoneViewport(tester);
      var taps = 0;
      await tester.pumpWidget(
        host(
          KakaoLoginButton(isLoading: false, onPressed: () => taps++),
          TargetPlatform.iOS,
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KakaoLoginButton),
          matching: find.byType(Container),
        ),
      );
      final deco = container.decoration! as ShapeDecoration;
      expect(deco.color, const Color(0xFFFEE500));
      expect(deco.shape, const StadiumBorder());
      expect(tester.getSize(find.byType(KakaoLoginButton)).height, 50);
      expect(find.text('카카오로 시작하기'), findsOneWidget);

      await tester.tap(find.text('카카오로 시작하기'));
      expect(taps, 1);
    });

    testWidgets('iOS: 로딩 중에는 CupertinoActivityIndicator를 보이고 탭을 무시한다', (tester) async {
      useIphoneViewport(tester);
      var taps = 0;
      await tester.pumpWidget(
        host(
          KakaoLoginButton(isLoading: true, onPressed: () => taps++),
          TargetPlatform.iOS,
        ),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('카카오로 시작하기'), findsNothing);
      await tester.tap(find.byType(KakaoLoginButton));
      expect(taps, 0);
    });

    testWidgets('iOS: 큰 글자와 좁은 폭에서도 넘침 없이 말줄임 처리한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: KakaoLoginButton(isLoading: false, onPressed: () {}),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('카카오로 시작하기'));
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Android: base와 같은 값(ElevatedButton, 높이 48, 반경 12, 색, 글자 16/w700)을 유지한다', (
      tester,
    ) async {
      useAndroidViewport(tester); // 폭 420dp -> responsive 배율 1.0
      await tester.pumpWidget(
        host(
          KakaoLoginButton(isLoading: false, onPressed: () {}),
          TargetPlatform.android,
        ),
      );

      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style!.backgroundColor!.resolve({}), const Color(0xFFFEE500));
      expect(button.style!.foregroundColor!.resolve({}), const Color(0xFF191919));
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFFEE500),
      );
      expect(button.style!.elevation!.resolve({}), 0);
      expect(
        button.style!.shape!.resolve({}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      expect(tester.getSize(find.byType(ElevatedButton)).height, 48);
      final text = tester.widget<Text>(find.text('카카오로 시작하기'));
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.style!.color, const Color(0xFF191919));
    });

    testWidgets('Android: 로딩은 기존 CircularProgressIndicator(두께 2, 20x20 박스)이고 버튼이 비활성이다', (
      tester,
    ) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(
        host(
          KakaoLoginButton(isLoading: true, onPressed: () {}),
          TargetPlatform.android,
        ),
      );

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 2);
      expect(tester.getSize(find.byType(CircularProgressIndicator)), const Size(20, 20));
    });
  });

  group('LoginPage 카카오 로그인 중복 탭 가드(iOS)', () {
    Future<void> openSheet(WidgetTester tester, AuthProviderClient client) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(
        buildAuthApp(
          LoginPage(kakaoClientFactory: () => client),
          TargetPlatform.iOS,
        ),
      );
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
    }

    testWidgets('시트가 닫히는 동안 연타해도 로그인은 1회만 시작한다', (
      tester,
    ) async {
      final client = _SlowCancelClient(const Duration(milliseconds: 500));
      await openSheet(tester, client);

      // 시트가 닫히는 동안 버튼을 연타해도 닫히는 라우트가 포인터를 막아
      // 로그인은 1회만 시작된다.
      final button = find.text('카카오로 시작하기');
      final center = tester.getCenter(button);
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(client.calls, 1);
      // 재시도는 아래 두 테스트(끝나지 않는 signIn, 예외)에서 확인한다. 여기서
      // 두 번째 탭은 닫히는 시트의 배리어를 통과해 뒤 화면에 닿을 수 있다
      // (W2 showAppSheet 후속 과제).
    });

    testWidgets('signIn이 끝나지 않아도(카카오톡에서 그냥 돌아옴) 다시 탭하면 새 로그인을 시작한다', (tester) async {
      final client = _NeverCompletingClient();
      await openSheet(tester, client);

      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();
      expect(client.calls, 1);

      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();
      expect(client.calls, 2);
      expect(find.byType(KakaoLoginButton), findsNothing, reason: '시트가 닫혀야 한다');
    });

    testWidgets('실패(예외) 후에도 오류 알럿을 보여주고 다시 시도할 수 있다', (tester) async {
      final client = _ThrowingClient();
      await openSheet(tester, client);

      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();
      expect(client.calls, 1);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('로그인 실패'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();
      expect(client.calls, 2);
    });
  });
}
