import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/core/auth/session_bootstrapper.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/kakao_login_button.dart';
import 'package:after30/utils/responsive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Future<void> _handleKakaoLogin() async {
    try {
      await SessionBootstrapper.completeLogin(
        context,
        KakaoAuthProviderClient(),
      );
    } catch (e) {
      if (!mounted) return;
      await showAppAlert(
        context: context,
        title: '로그인 실패',
        message: '로그인 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 로그인 옵션 시트에 나열할 항목들을 리스트로 구성한다(plan §6 W3a
  /// 3항). Apple 로그인 버튼(W3b)은 이 목록의 맨 앞에 추가하기만 하면 되고,
  /// 다른 부분은 손댈 필요가 없다.
  List<Widget> _loginOptions(BuildContext sheetContext) {
    return [
      KakaoLoginButton(
        isLoading: false,
        onPressed: () {
          Navigator.of(sheetContext).pop();
          _handleKakaoLogin();
        },
      ),
      SizedBox(height: Responsive.responsiveHeight(sheetContext, 12)),
      AppButton(
        label: '이메일로 로그인',
        variant: AppButtonVariant.outline,
        size: AppButtonSize.medium,
        onPressed: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pushNamed('/email-login');
        },
      ),
    ];
  }

  Future<void> _showLoginOptionsSheet() async {
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _loginOptions(sheetContext),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
            const double buttonsLift = 20.0;
            const double logoLift = 42.0; // 로고를 살짝 위로
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -logoLift),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 중앙 로고 (고정)
                        SvgPicture.asset(
                          'assets/images/logowithname.svg',
                          width: Responsive.responsiveValue(context, 140),
                          height: Responsive.responsiveValue(context, 140),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.responsiveValue(context, 39),
                      0,
                      Responsive.responsiveValue(context, 39),
                      bottomSafe +
                          Responsive.responsiveValue(context, 39) +
                          buttonsLift,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppButton(
                          label: '회원가입',
                          onPressed: () {
                            Navigator.of(context).pushNamed('/signup-intro');
                          },
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 12),
                        ),
                        AppButton(
                          label: '로그인',
                          variant: AppButtonVariant.outline,
                          onPressed: _showLoginOptionsSheet,
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
