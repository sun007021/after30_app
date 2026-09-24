import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:after30/core/config/api_config.dart';
import 'package:after30/core/storage/token_store.dart';

class ApiClient {
  ApiClient._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          contentType: 'application/json',
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 리뷰 M1①: 이 블록 안에서 예외가 나면(예: 보안 저장소 접근
          // 실패) handler.next/reject가 둘 다 호출되지 않아 요청이 영원히
          // 멈춘다. SharedPreferences 시절에는 이런 예외가 없었지만
          // Keychain/Keystore 이전(D8) 이후로는 실제로 발생할 수 있다
          // (iOS: 기기 잠금 중 백그라운드 알림 액션, Android: Auto
          // Backup으로 새 기기에 복원된 파일에 Keystore 키가 없는 경우,
          // 테스트 환경 등). 이제는 TokenStore가 이런 예외를 이미 삼키고
          // null을 반환하지만(M1②), 그래도 방어적으로 인터셉터 전체를
          // try/catch로 감싸 어떤 경우에도 next 또는 reject 중 하나는
          // 반드시 호출되게 한다.
          try {
            final skipAuth = options.extra['skipAuth'] == true;
            if (!skipAuth && ApiConfig.authMode == AuthMode.bearer) {
              final token = await TokenStore.getAccessToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            final query = options.queryParameters;
            final querySuffix = query.isNotEmpty ? '?$query' : '';
            if (kDebugMode) {
              debugPrint('➡️  ${options.method} ${options.path}$querySuffix');
            }
            handler.next(options);
          } catch (e) {
            handler.reject(DioException(requestOptions: options, error: e));
          }
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final skipAuth = error.requestOptions.extra['skipAuth'] == true;
          final noRefresh = error.requestOptions.extra['noRefresh'] == true;
          if (!skipAuth && !noRefresh && _shouldAttemptRefresh(error)) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              try {
                final req = await _retryRequest(error.requestOptions);
                return handler.resolve(req);
              } catch (_) {}
            }
          }
          if (kDebugMode) {
            debugPrint(
              '❌ ${error.response?.statusCode ?? '-'} ${error.requestOptions.method} ${error.requestOptions.path}',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final Dio _dio;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshWaiters = [];

  Dio get dio => _dio;

  bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode == 401) {
      return ApiConfig.authMode == AuthMode.bearer;
    }
    return false;
  }

  Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) {
      final waiter = Completer<void>();
      _refreshWaiters.add(waiter);
      await waiter.future;
      return (await TokenStore.getAccessToken()) != null;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await TokenStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }
      final resp = await _dio.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = resp.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String?;
      final accessExp = (data['access_expires_in'] as num?)?.toInt() ?? 0;
      if (newAccess == null || newAccess.isEmpty) return false;
      await TokenStore.saveTokens(
        accessToken: newAccess,
        refreshToken: refreshToken,
        accessExpiresIn: accessExp,
        refreshExpiresIn: 0,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
      for (final w in _refreshWaiters) {
        if (!w.isCompleted) w.complete();
      }
      _refreshWaiters.clear();
    }
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}
