import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/features/login/models/auth_models.dart';

/// 로그인 제공자별 백엔드 인증 클라이언트 공통 인터페이스(plan §6 W3a 1항).
///
/// 각 구현체는 자신의 로그인 SDK/폼을 다루고, 성공하면 백엔드 토큰 응답
/// ([KakaoLoginResponse] — 카카오·이메일 로그인 모두 같은 페이로드 모양을
/// 쓴다)을 반환한다. 로그인 이후 공통 처리(토큰 저장, 사용자 ID 통합,
/// 알람 재스케줄, FCM 동기화, 셸 진입)는 이 인터페이스가 아니라
/// `SessionBootstrapper`가 도맡는다 — Apple 로그인(W3b)을 추가할 때도 이
/// 인터페이스를 구현하는 클라이언트 하나만 더하면 된다.
abstract class AuthProviderClient {
  /// 제공자 식별자('kakao', 'email'). 백엔드 `/users/me`의 `provider`와
  /// 값이 같다.
  String get providerId;

  /// 로그인을 수행한다. 사용자가 취소한 경우(예: 카카오 로그인 팝업을
  /// 닫음) 예외를 던지지 않고 null을 반환한다 — 호출부는 이 경우 아무
  /// 안내도 띄우지 않고 조용히 멈춘다(기존 `login.dart`/`signup_intro.dart`
  /// 동작 유지).
  Future<AuthSignInResult?> signIn();
}

/// 로그인 성공 결과.
class AuthSignInResult {
  const AuthSignInResult({
    required this.tokens,
    this.fallbackUserId,
    this.legacyUserIds = const [],
  });

  /// 백엔드가 내려준 토큰 페이로드.
  final KakaoLoginResponse tokens;

  /// JWT에서 사용자 ID를 파싱하지 못했을 때 대신 쓸 식별자(이메일 로그인의
  /// 경우 이메일 주소). 대부분의 경우 JWT 파싱이 성공하므로 쓰이지 않는다.
  final String? fallbackUserId;

  /// 예전 버전이 "현재 사용자 ID"로 저장했던, **이번에 로그인한 계정 자신의**
  /// 식별자 후보들(리뷰 M2/M3). `SessionBootstrapper`가 이 값들에서만
  /// 로컬 알람 데이터를 새 백엔드 ID로 옮긴다.
  ///
  /// `UserStore`에 남아있는 "이전 사용자 ID"를 그대로 마이그레이션 소스로
  /// 쓰면 안 된다 — 로그아웃 시 `UserStore`는 비워지므로 재로그인 시
  /// 이전 값을 잃어버리고(알람이 옛 네임스페이스에 갇힘), 반대로 다른
  /// 계정이 로그아웃하지 않은 채 남겨둔 값이 있으면(예: 부모 폰에 자녀가
  /// 로그인) 그 계정의 알람을 엉뚱하게 새 계정으로 옮겨버릴 수 있다. 이
  /// 후보 목록은 오직 지금 로그인에 성공한 계정 자신의 예전 식별자만
  /// 담는다.
  final List<String> legacyUserIds;
}

/// 카카오 로그인 클라이언트. 카카오톡 앱이 설치돼 있으면 앱 로그인을 먼저
/// 시도하고, 실패하거나 설치돼 있지 않으면 카카오 계정(웹) 로그인으로
/// 넘어간다(기존 `login.dart`/`signup_intro.dart` 로직을 그대로 옮김).
class KakaoAuthProviderClient implements AuthProviderClient {
  @override
  String get providerId => 'kakao';

  @override
  Future<AuthSignInResult?> signIn() async {
    OAuthToken? kakaoToken;
    final kakaoTalkInstalled = await isKakaoTalkInstalled();
    if (kakaoTalkInstalled) {
      try {
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } catch (error) {
        if (error is PlatformException && error.code == 'CANCELED') {
          return null;
        }
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      kakaoToken = await UserApi.instance.loginWithKakaoAccount();
    }

    final tokens = await BackendAuthService().loginWithKakaoAccessToken(
      kakaoToken.accessToken,
    );

    // 예전 버전은 카카오 회원 ID를 "현재 사용자 ID"로 저장했다(plan §1.5).
    // 그 시절 데이터를 옮기기 위한 마이그레이션 후보로만 쓴다 — 최선을
    // 다해 조회하고, 실패해도 로그인 자체는 계속 진행한다.
    String? kakaoUserId;
    try {
      final me = await UserApi.instance.me();
      kakaoUserId = me.id.toString();
    } catch (_) {}

    return AuthSignInResult(
      tokens: tokens,
      fallbackUserId: kakaoUserId,
      legacyUserIds: kakaoUserId != null ? [kakaoUserId] : const [],
    );
  }
}

/// 이메일 로그인 클라이언트.
class EmailAuthProviderClient implements AuthProviderClient {
  EmailAuthProviderClient({required this.email, required this.password});

  final String email;
  final String password;

  @override
  String get providerId => 'email';

  @override
  Future<AuthSignInResult?> signIn() async {
    final tokens = await BackendAuthService().loginWithEmail(
      email: email,
      password: password,
    );
    // JWT 파싱이 실패하는 드문 경우를 대비해 이메일을 대체 식별자로 둔다
    // (기존 email_login_page.dart 동작 유지). 예전 버전은 이메일 자체를
    // "현재 사용자 ID"로 저장했으므로 마이그레이션 후보이기도 하다.
    return AuthSignInResult(
      tokens: tokens,
      fallbackUserId: email,
      legacyUserIds: [email],
    );
  }
}
