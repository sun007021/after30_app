class ApiConfig {
  // 백엔드 베이스 URL
  static const String baseUrl = 'http://43.202.88.108:8000';

  // 인증 모드: Bearer 또는 Cookie
  static const AuthMode authMode = AuthMode.bearer;

  // 카카오 리다이렉트 URI (카카오 개발자 콘솔에 등록되어 있어야 함)
  // 기본 형태: kakao{NATIVE_APP_KEY}://oauth
  static const String kakaoRedirectUri =
      'kakao54b330c450ea6d30f52c96937e871989://oauth';

  // 카카오 네이티브 앱 키 (인가코드 authorize 시 clientId)
  static const String kakaoNativeAppKey = '54b330c450ea6d30f52c96937e871989';
}

enum AuthMode { bearer, cookie }
