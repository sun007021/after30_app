// 디버그 전용 프리뷰 엔트리포인트(plan §6 W6 검증 절차).
//
// 로그인/가입/약관/온보딩 화면은 백엔드 세션 없이도 그려지므로 Firebase/Kakao
// 초기화 없이 시뮬레이터에서 iOS 스타일을 눈으로 확인할 수 있다.
// `flutter build ios --simulator`는 Xcode 26.6 + Flutter 3.38.3 조합에서
// lipo 오류로 실패하므로(plan §3 각주), 다음처럼 실행한다.
//
//   flutter run -d <simulator> -t lib/dev/signup_preview_main.dart --no-resident
//
// 시뮬레이터에 터치 입력을 보낼 수 없는 환경이라, 화면을 [_interval]마다
// 순서대로 자동 전환한다(login → signup → terms → intro → onboarding 반복).
// 화면 코드는 건드리지 않는다. 릴리스 진입점이 아니므로 main.dart에서
// import하지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/login/ui/signup_intro.dart';
import 'package:after30/features/login/ui/signup_page.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';
import 'package:after30/features/onboarding/ui/onboarding_page.dart';

const _interval = Duration(seconds: 12);

final _navKey = GlobalKey<NavigatorState>();

final List<WidgetBuilder> _screens = [
  (_) => const EmailLoginPage(),
  (_) => const SignupPage(),
  (_) => const TermsAgreementPage(),
  (_) => const SignupIntroPage(),
  (_) => const OnboardingPage(),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SignupPreviewApp());
  var index = 0;
  Timer.periodic(_interval, (_) {
    index = (index + 1) % _screens.length;
    _navKey.currentState?.pushReplacement(
      MaterialPageRoute<void>(builder: _screens[index]),
    );
  });
}

class _SignupPreviewApp extends StatelessWidget {
  const _SignupPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가입 프리뷰',
      navigatorKey: _navKey,
      theme: AppTheme.build(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (_) => const SizedBox.shrink(),
        '/signup': (_) => const SignupPage(),
        '/signup-terms': (_) => const TermsAgreementPage(),
        '/email-login': (_) => const EmailLoginPage(),
      },
      home: const EmailLoginPage(),
    );
  }
}
