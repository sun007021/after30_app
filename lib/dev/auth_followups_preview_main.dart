// 디버그 전용 프리뷰 엔트리포인트(W3a 후속 검증용).
//
// 로그인 카카오 버튼(로그인 옵션 시트)과 탈퇴 확인/실패 알럿의 iOS 스타일을
// 시뮬레이터에서 눈으로 확인한다. 터치 입력을 보낼 수 없는 환경이라 장면을
// [_interval]마다 자동 전환한다(login → 로그인 시트 → 탈퇴 확인 → 탈퇴 실패).
//
//   flutter run -d <simulator> -t lib/dev/auth_followups_preview_main.dart --no-resident
//
// 릴리스 진입점이 아니므로 main.dart에서 import하지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/kakao_login_button.dart';
import 'package:after30/features/login/ui/login.dart';

const _interval = Duration(seconds: 10);

final _navKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PreviewApp());
  var scene = 0;
  Timer.periodic(_interval, (_) async {
    scene = (scene + 1) % 4;
    final nav = _navKey.currentState;
    final context = _navKey.currentContext;
    if (nav == null || context == null) return;
    nav.popUntil((route) => route.isFirst);
    switch (scene) {
      case 0:
        break;
      case 1:
        unawaited(
          showAppSheet<void>(
            context: context,
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KakaoLoginButton(isLoading: false, onPressed: () {}),
                  const SizedBox(height: 12),
                  AppButton(
                    label: '이메일로 로그인',
                    variant: AppButtonVariant.outline,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );
      case 2:
        unawaited(
          showAppConfirm(
            context: context,
            title: "정말 '식후30분'을 떠나시나요?",
            message: '그동안의 모든 기록과 가족 연결 정보가 사라집니다. 정말 탈퇴하시겠습니까?',
            cancelLabel: '유지하기',
            confirmLabel: '탈퇴하기',
          ),
        );
      case 3:
        unawaited(
          showAppAlert(
            context: context,
            title: '탈퇴 실패',
            message: '비밀번호가 올바르지 않습니다.',
          ),
        );
    }
  });
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '인증 후속 프리뷰',
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
      home: const LoginPage(),
    );
  }
}
