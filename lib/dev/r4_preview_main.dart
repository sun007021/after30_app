// 디버그 전용 프리뷰 엔트리포인트(R4 다듬기 검증 절차).
//
// 온보딩과 "가입 직후 루트에 이메일 로그인만 남은" 화면을 시뮬레이터에서
// 확인한다. 릴리스 진입점이 아니므로 main.dart에서 import하지 않는다.
//
//   flutter run -d <simulator> -t lib/dev/r4_preview_main.dart \
//     --dart-define=SCENE=onboarding|email-login --no-resident
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/onboarding/ui/onboarding_page.dart';

const _scene = String.fromEnvironment('SCENE', defaultValue: 'onboarding');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'R4 프리뷰',
      theme: AppTheme.build(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      debugShowCheckedModeBanner: false,
      routes: {'/login': (_) => const SizedBox.shrink()},
      home: _scene == 'email-login' ? const EmailLoginPage() : const OnboardingPage(),
    ),
  );
}
