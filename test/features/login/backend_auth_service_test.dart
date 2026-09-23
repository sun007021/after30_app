import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';

import '../../core/storage/fake_secure_storage.dart';

/// 백엔드 로그인/가입/리프레시 API를 dio 인터셉터로 목킹해 실제 네트워크
/// 없이 검증한다(plan §6 W3a 완료 조건).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  Interceptor? mockInterceptor;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    TokenStore.debugOverrideSecureStorage(fakeStorage);
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
    });
  });

  tearDown(() {
    if (mockInterceptor != null) {
      ApiClient().dio.interceptors.remove(mockInterceptor);
    }
    TokenStore.debugReset();
  });

  void mockResponse({
    required String path,
    int statusCode = 200,
    Map<String, dynamic>? data,
  }) {
    mockInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path != path) {
          handler.reject(
            DioException(requestOptions: options, message: '예상하지 못한 경로: ${options.path}'),
          );
          return;
        }
        if (statusCode >= 200 && statusCode < 300) {
          handler.resolve(
            Response(requestOptions: options, statusCode: statusCode, data: data),
          );
        } else {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: statusCode, data: data),
              type: DioExceptionType.badResponse,
            ),
          );
        }
      },
    );
    ApiClient().dio.interceptors.add(mockInterceptor!);
  }

  group('loginWithEmail', () {
    test('성공하면 토큰을 저장하고 응답을 반환한다', () async {
      mockResponse(
        path: '/auth/login/email',
        data: {
          'access_token': 'access-1',
          'refresh_token': 'refresh-1',
          'access_expires_in': 3600,
          'refresh_expires_in': 86400,
          'is_new_user': false,
        },
      );

      final result = await BackendAuthService().loginWithEmail(
        email: 'user@example.com',
        password: 'pw1234',
      );

      expect(result.accessToken, 'access-1');
      expect(await TokenStore.getAccessToken(), 'access-1');
      expect(await TokenStore.getRefreshToken(), 'refresh-1');
    });

    test('401 응답이면 상태 코드를 포함한 예외를 던진다', () async {
      mockResponse(
        path: '/auth/login/email',
        statusCode: 401,
        data: {'detail': '이메일 또는 비밀번호가 일치하지 않습니다.'},
      );

      await expectLater(
        BackendAuthService().loginWithEmail(email: 'user@example.com', password: 'wrong'),
        throwsA(
          predicate((e) => e.toString().contains('401') && e.toString().contains('이메일 로그인 실패')),
        ),
      );
      expect(await TokenStore.getAccessToken(), isNull);
    });
  });

  group('loginWithKakaoAccessToken', () {
    test('성공하면 토큰을 저장한다', () async {
      mockResponse(
        path: '/auth/login/kakao',
        data: {
          'access_token': 'kakao-access',
          'refresh_token': 'kakao-refresh',
          'access_expires_in': 3600,
          'refresh_expires_in': 86400,
          'is_new_user': true,
        },
      );

      final result = await BackendAuthService().loginWithKakaoAccessToken('kakao-sdk-token');

      expect(result.isNewUser, isTrue);
      expect(await TokenStore.getAccessToken(), 'kakao-access');
    });
  });

  group('refreshSession', () {
    test('저장된 리프레시 토큰이 없으면 네트워크를 타지 않고 false를 반환한다', () async {
      final ok = await BackendAuthService().refreshSession();
      expect(ok, isFalse);
    });

    test('성공하면 새 액세스 토큰을 저장하고 true를 반환한다', () async {
      await TokenStore.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'refresh-1',
        accessExpiresIn: 0,
        refreshExpiresIn: 86400,
      );
      mockResponse(
        path: '/auth/token/refresh',
        data: {'access_token': 'new-access', 'access_expires_in': 3600},
      );

      final ok = await BackendAuthService().refreshSession();

      expect(ok, isTrue);
      expect(await TokenStore.getAccessToken(), 'new-access');
      // 리프레시 토큰 자체는 그대로 유지된다.
      expect(await TokenStore.getRefreshToken(), 'refresh-1');
    });

    test('실패 응답이면 false를 반환하고 기존 토큰을 건드리지 않는다', () async {
      await TokenStore.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'refresh-1',
        accessExpiresIn: 0,
        refreshExpiresIn: 86400,
      );
      mockResponse(path: '/auth/token/refresh', statusCode: 401, data: {'detail': '만료됨'});

      final ok = await BackendAuthService().refreshSession();

      expect(ok, isFalse);
      expect(await TokenStore.getAccessToken(), 'old-access');
    });
  });
}
