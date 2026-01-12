class ApiConfig {
  // 로컬 백엔드 (Android 에뮬레이터는 10.0.2.2 = Mac의 localhost)
  //static const String baseUrl = 'http://10.0.2.2:8000/';
  static const String baseUrl = 'https://api.pysun.kr/';
  static const AuthMode authMode = AuthMode.bearer;
  static const String kakaoRedirectUri =
      'kakao54b330c450ea6d30f52c96937e871989://oauth';
  static const String kakaoNativeAppKey = '54b330c450ea6d30f52c96937e871989';
}

enum AuthMode { bearer, cookie }
