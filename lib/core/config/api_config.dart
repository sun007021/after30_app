class ApiConfig {
  static const String baseUrl = 'http://43.202.88.108:8000';
  static const AuthMode authMode = AuthMode.bearer;
  static const String kakaoRedirectUri =
      'kakao54b330c450ea6d30f52c96937e871989://oauth';
  static const String kakaoNativeAppKey = '54b330c450ea6d30f52c96937e871989';
}

enum AuthMode { bearer, cookie }
