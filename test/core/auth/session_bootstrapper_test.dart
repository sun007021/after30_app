import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/core/auth/session_bootstrapper.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/login/models/auth_models.dart';

import '../../support/fake_secure_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final encodedPayload = base64Url
      .encode(utf8.encode(json.encode(payload)))
      .replaceAll('=', '');
  return 'header.$encodedPayload.signature';
}

KakaoLoginResponse _fakeTokens({required String accessToken}) {
  return KakaoLoginResponse(
    accessToken: accessToken,
    refreshToken: 'refresh-token',
    accessExpiresIn: 3600,
    refreshExpiresIn: 86400,
    isNewUser: false,
  );
}

/// 실제 카카오/이메일 로그인 SDK를 타지 않는 가짜 제공자.
///
/// 실제 구현체(`KakaoAuthProviderClient`/`EmailAuthProviderClient`)는
/// `BackendAuthService`를 통해 로그인에 성공하면 그 안에서 이미
/// `TokenStore.saveTokens`까지 마친 뒤 결과를 반환한다. 이 가짜도 같은
/// 계약을 지켜야 `SessionBootstrapper`가 그 뒤 `CurrentUserResolver`로 JWT를
/// 읽을 수 있다.
class _FakeAuthProviderClient implements AuthProviderClient {
  _FakeAuthProviderClient(this._result);

  final AuthSignInResult? _result;

  @override
  String get providerId => 'fake';

  @override
  Future<AuthSignInResult?> signIn() async {
    final result = _result;
    if (result == null) return null;
    await TokenStore.saveTokens(
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
      accessExpiresIn: result.tokens.accessExpiresIn,
      refreshExpiresIn: result.tokens.refreshExpiresIn,
    );
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  late Interceptor blockNetworkInterceptor;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    TokenStore.debugOverrideSecureStorage(fakeStorage);
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
    });
    // 기본적으로는 실제 네트워크를 막는다("dio 목" 방식) — 개별 테스트가
    // 필요하면 자신만의 interceptor로 교체한다.
    blockNetworkInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, message: '테스트 환경 네트워크 차단'),
        );
      },
    );
    ApiClient().dio.interceptors.add(blockNetworkInterceptor);
  });

  tearDown(() {
    ApiClient().dio.interceptors.remove(blockNetworkInterceptor);
    TokenStore.debugReset();
  });

  testWidgets('로그인 성공: 사용자 ID를 통합하고 셸(/home)로 진입한다', (tester) async {
    // 카카오 ID로 저장돼 있던 예전 알람 데이터(마이그레이션 대상).
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
      'current_user_id': '1234567',
      'medicine_alarms_1234567': '[]',
    });

    // M2/M3: 마이그레이션 소스는 UserStore가 아니라 이번에 로그인한 계정
    // 자신의 예전 식별자 후보(legacyUserIds)다. 카카오 클라이언트가
    // `UserApi.instance.me().id`로 채우는 값을 흉내낸다.
    final fakeClient = _FakeAuthProviderClient(
      AuthSignInResult(
        tokens: _fakeTokens(accessToken: _fakeJwt({'sub': 42})),
        legacyUserIds: const ['1234567'],
      ),
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/home': (_) => const Scaffold(body: Text('홈')),
        },
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    await SessionBootstrapper.completeLogin(capturedContext, fakeClient);
    await tester.pumpAndSettle();

    // 백엔드 ID로 통일됐어야 한다(카카오 ID가 아니라).
    expect(await UserStore.getCurrentUserId(), '42');
    // 예전 카카오 ID 키의 데이터가 새 ID 키로 옮겨졌어야 한다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_42'), '[]');
    expect(prefs.getString('medicine_alarms_1234567'), isNull);
    // 셸(홈)로 진입했어야 한다.
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets('로그인 취소(null 반환): 아무 것도 하지 않고 이동하지 않는다', (tester) async {
    final cancelledClient = _FakeAuthProviderClient(null);

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/home': (_) => const Scaffold(body: Text('홈')),
        },
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: Text('로그인 화면'));
          },
        ),
      ),
    );

    await SessionBootstrapper.completeLogin(capturedContext, cancelledClient);
    await tester.pumpAndSettle();

    expect(await UserStore.getCurrentUserId(), isNull);
    expect(find.text('로그인 화면'), findsOneWidget);
    expect(find.text('홈'), findsNothing);
  });

  test('restore(): 리프레시 토큰이 없으면 false를 반환하고 후처리를 하지 않는다', () async {
    final restored = await SessionBootstrapper.restore();

    expect(restored, isFalse);
    expect(await UserStore.getCurrentUserId(), isNull);
  });

  test('restore(): 세션 복원 성공 시 사용자 ID를 통합한다(이메일 폴백 → 백엔드 ID)', () async {
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
      'current_user_id': 'user@example.com',
      'medicine_alarms_user@example.com': '[]',
    });
    await TokenStore.saveTokens(
      accessToken: 'expired-access',
      refreshToken: 'valid-refresh',
      accessExpiresIn: 0,
      refreshExpiresIn: 86400,
    );

    // 세션 복원 API를 성공 응답으로 흉내낸다.
    ApiClient().dio.interceptors.remove(blockNetworkInterceptor);
    final fakeRefresh = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/auth/token/refresh') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'access_token': _fakeJwt({'sub': 99}),
                'access_expires_in': 3600,
              },
            ),
          );
          return;
        }
        handler.reject(
          DioException(requestOptions: options, message: '테스트 환경 네트워크 차단'),
        );
      },
    );
    ApiClient().dio.interceptors.add(fakeRefresh);
    addTearDown(() => ApiClient().dio.interceptors.remove(fakeRefresh));

    final restored = await SessionBootstrapper.restore();

    expect(restored, isTrue);
    expect(await UserStore.getCurrentUserId(), '99');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_99'), '[]');
    expect(prefs.getString('medicine_alarms_user@example.com'), isNull);
  });
}
