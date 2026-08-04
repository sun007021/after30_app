import 'dart:async';
import 'package:dio/dio.dart';
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
          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth && ApiConfig.authMode == AuthMode.bearer) {
            final token = await TokenStore.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          final query = options.queryParameters;
          final querySuffix = query.isNotEmpty ? '?$query' : '';
          // ignore: avoid_print
          print('➡️  ${options.method} ${options.path}$querySuffix');
          handler.next(options);
        },
        onResponse: (response, handler) {
          // ignore: avoid_print
          print(
            '✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
          );
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
          // ignore: avoid_print
          print(
            '❌ ${error.response?.statusCode ?? '-'} ${error.requestOptions.method} ${error.requestOptions.path}',
          );
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
