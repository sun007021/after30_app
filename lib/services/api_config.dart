class ApiConfig {
  // 개발 환경
  static const String devBaseUrl = 'http://localhost:3000/api';

  // 프로덕션 환경
  static const String prodBaseUrl = 'https://your-production-server.com/api';

  // 현재 사용할 URL (개발/프로덕션 환경에 따라 변경)
  static const String baseUrl = devBaseUrl;

  // API 엔드포인트들
  static const String kakaoLoginEndpoint = '/auth/login/kakao';
  static const String tokenRefreshEndpoint = '/auth/token/refresh';
  static const String userProfileEndpoint = '/user/profile';

  // 전체 URL들
  static String get kakaoLoginUrl => '$baseUrl$kakaoLoginEndpoint';
  static String get tokenRefreshUrl => '$baseUrl$tokenRefreshEndpoint';
  static String get userProfileUrl => '$baseUrl$userProfileEndpoint';
}
