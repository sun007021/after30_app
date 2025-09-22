import 'package:after30/services/api_client.dart';
import 'package:after30/models/api/auth_models.dart';
import 'package:after30/services/token_store.dart';
import 'package:dio/dio.dart';

class BackendAuthService {
  final _client = ApiClient().dio;

  /// 백엔드 카카오 로그인: POST /auth/login/kakao
  /// Body: { "access_token": "<카카오 액세스 토큰>", "code": "<인가코드>" }
  Future<KakaoLoginResponse> loginWithKakaoAccessToken(
    String accessToken, {
    String? code,
  }) async {
    try {
      final resp = await _client.post(
        '/auth/login/kakao',
        data: {'access_token': accessToken},
        options: Options(
          // 로그인 교환 요청은 기존 서비스 토큰 주입/리프레시를 건너뜀
          extra: {'skipAuth': true},
          headers: {
            'Content-Type': 'application/json',
            // 일부 서버 구현 호환: 헤더에도 Bearer 전달
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      final data = KakaoLoginResponse.fromJson(
        (resp.data as Map<String, dynamic>),
      );
      await TokenStore.saveTokens(
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        accessExpiresIn: data.accessExpiresIn,
        refreshExpiresIn: data.refreshExpiresIn,
      );
      return data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      // 디버깅 편의를 위해 상세 원인을 예외로 전달
      throw Exception('백엔드 카카오 로그인 실패 ($status): $body');
    }
  }

  /// 새 액세스 토큰 발급: POST /auth/token/refresh
  /// Body: { "refresh_token": "<리프레시 토큰>" }
  Future<bool> refreshSession() async {
    try {
      final refreshToken = await TokenStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }
      final resp = await _client.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: {'skipAuth': true},
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final data = RefreshTokenResponse.fromJson(
        (resp.data as Map<String, dynamic>),
      );
      await TokenStore.saveTokens(
        accessToken: data.accessToken,
        refreshToken: refreshToken,
        accessExpiresIn: data.accessExpiresIn,
        refreshExpiresIn: 0,
      );
      return true;
    } on DioException catch (_) {
      return false;
    }
  }
}
