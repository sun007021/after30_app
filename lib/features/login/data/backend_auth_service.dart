import 'package:after30/core/network/api_client.dart';
import 'package:after30/features/login/models/auth_models.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
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
      // 서버 회원가입 스키마에는 gender 필드가 없어 무시되므로,
      // 토큰 저장 직후 별도로 PATCH /users/me 를 호출해 성별을 저장한다.
      // 이 저장이 실패하더라도 회원가입 자체는 성공으로 처리한다.
      if (gender.trim().isNotEmpty) {
        try {
          await _client.patch(
            '/users/me',
            data: {'gender': MyProfile.genderToApi(gender)},
          );
        } catch (_) {
          // 성별 저장 실패는 무시한다 (가입 실패로 취급하지 않음).
        }
      }
      return data;
    } on DioException catch (e) {
      final body = e.response?.data;
      final detail = _parseErrorDetail(body);
      throw Exception(detail.isNotEmpty ? detail : '회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  /// 서버 에러 응답의 `detail` 을 사람이 읽을 수 있는 메시지로 변환한다.
  /// `detail` 은 문자열이거나(FastAPI validation error) 배열일 수 있다.
  String _parseErrorDetail(dynamic body) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        final messages = detail
            .map((item) {
              if (item is Map && item['msg'] is String) {
                return (item['msg'] as String).replaceFirst(
                  RegExp(r'^Value error,\s*'),
                  '',
                );
              }
              return item?.toString() ?? '';
            })
            .where((m) => m.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    } else if (body is String) {
      return body;
    }
    return '';
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
