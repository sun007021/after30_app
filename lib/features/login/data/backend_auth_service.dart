import 'package:after30/core/network/api_client.dart';
import 'package:after30/features/login/models/auth_models.dart';
import 'package:after30/core/storage/token_store.dart';
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
          headers: {'Content-Type': 'application/json'},
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

  /// 이메일 로그인: POST /auth/login/email
  /// Body: { "email": "<이메일>", "password": "<비밀번호>" }
  /// 응답은 카카오 로그인과 동일한 토큰 페이로드라고 가정
  Future<KakaoLoginResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client.post(
        '/auth/login/email',
        data: {'email': email, 'password': password},
        options: Options(
          extra: {'skipAuth': true},
          headers: {'Content-Type': 'application/json'},
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
      throw Exception('이메일 로그인 실패 ($status): $body');
    }
  }

  /// 이메일 회원가입: POST /auth/register
  /// Body: { "name": "<이름>", "gender": "<남|여>", "email": "<이메일>", "password": "<비밀번호>" }
  /// 응답은 토큰 페이로드라고 가정 (가입 후 자동 로그인)
  Future<KakaoLoginResponse> registerWithEmail({
    required String name,
    required String gender,
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client.post(
        '/auth/register/email',
        data: {
          'name': name,
          'gender': gender,
          'email': email,
          'password': password,
        },
        options: Options(
          extra: {'skipAuth': true},
          headers: {'Content-Type': 'application/json'},
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
      final body = e.response?.data;
      String? detail;
      if (body is Map && body['detail'] is String) {
        detail = body['detail'] as String;
      } else if (body is String) {
        detail = body;
      }
      throw Exception(detail ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.');
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
