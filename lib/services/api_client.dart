import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:after30/services/token_provider.dart';
import 'package:after30/services/secure_storage_service.dart';
import 'auth_api_service.dart';

class ApiClient {
  final BuildContext context;
  ApiClient(this.context);

  Future<http.Response> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    dynamic body,
    bool withAuth = true,
    int retryCount = 1,
  }) async {
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    String? accessToken = tokenProvider.accessToken;
    String? refreshToken = tokenProvider.refreshToken;

    Map<String, String> reqHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    if (withAuth && accessToken != null) {
      reqHeaders['Authorization'] = 'Bearer $accessToken';
    }

    http.Response response;
    try {
      response = await _sendRequest(method, url, reqHeaders, body);
      if (response.statusCode == 401 &&
          withAuth &&
          retryCount > 0 &&
          refreshToken != null) {
        // access_token 만료 → refresh_token으로 재발급 시도
        final refreshResult = await AuthApiService.refreshToken(refreshToken);
        if (refreshResult['access_token'] != null &&
            refreshResult['refresh_token'] != null) {
          // 토큰 갱신 및 저장
          await tokenProvider.saveTokens(
            accessToken: refreshResult['access_token'],
            refreshToken: refreshResult['refresh_token'],
            expiresIn: refreshResult['expires_in'] ?? 0,
            refreshExpiresIn: refreshResult['refresh_expires_in'] ?? 0,
          );
          // 헤더 갱신 후 재시도
          reqHeaders['Authorization'] =
              'Bearer ${refreshResult['access_token']}';
          response = await _sendRequest(method, url, reqHeaders, body);
        } else {
          // refresh 실패 → 로그아웃 처리
          await tokenProvider.clearTokens();
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri url,
    Map<String, String> headers,
    dynamic body,
  ) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(url, headers: headers);
      case 'POST':
        return await http.post(url, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return await http.put(url, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }
}
