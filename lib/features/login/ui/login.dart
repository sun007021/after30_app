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
      _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (isCupertino(context)) {
      showAppAlert(context: context, title: '로그인 실패', message: message);
      return;
    }
    // Android는 리뷰 반영 전 기존 AlertDialog 외형을 그대로 유지한다.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인 실패'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 로그인 옵션 시트에 나열할 항목들을 리스트로 구성한다(plan §6 W3a
  /// 3항, iOS 전용). Apple 로그인 버튼(W3b)은 이 목록의 맨 앞에 추가하기만
  /// 하면 되고, 다른 부분은 손댈 필요가 없다.
  List<Widget> _loginOptionsIOS(BuildContext sheetContext) {
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

  Future<void> _showLoginOptionsSheetIOS() async {
    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _loginOptionsIOS(sheetContext),
          ),
        );
      },
    );
  }

  /// Android 전용: 리뷰 반영 전(§3 원칙 "Android 외형은 바꾸지 않는다") 코드와
  /// 동일한 마크업을 그대로 유지한다. `showAppSheet`/`AppButton`은 곡률·높이·
  /// 여백이 `Responsive` 스케일을 타지 않아 기존 Android 화면과 픽셀이
  /// 달라지므로(리뷰 지적), 이 화면에서는 Android 분기에 한해 원래 위젯을
  /// 직접 그린다.
  Future<void> _showLoginOptionsSheetAndroid() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFEBF0FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final bottomSafe = MediaQuery.of(ctx).viewPadding.bottom;
        return Padding(
          padding: Responsive.responsivePaddingLTRB(
            ctx,
            20,
            20,
            20,
            0,
          ).copyWith(bottom: bottomSafe + Responsive.responsiveValue(ctx, 72)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: Responsive.responsiveValue(ctx, 48),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Responsive.responsiveValue(ctx, 12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _handleKakaoLogin();
                      },
                      child: Container(
                        color: const Color(0xFFFEE500),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/kakao_chat.svg',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '카카오로 시작하기',
                              style: TextStyle(
                                color: Color(0xFF191919),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(ctx, 12)),
              SizedBox(
                height: Responsive.responsiveValue(ctx, 48),
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/email-login');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111111),
                    side: const BorderSide(color: Colors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Responsive.responsiveValue(ctx, 12),
                      ),
                    ),
                  ),
                  child: Text(
                    '이메일로 로그인',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(ctx, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return isCupertino(context) ? _buildIOS(context) : _buildAndroid(context);
  }

  /// iOS: W2 디자인 시스템(AppButton/showAppSheet/showAppAlert)으로 그린다.
  Widget _buildIOS(BuildContext context) {
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
                    child: SvgPicture.asset(
                      'assets/images/logowithname.svg',
                      width: Responsive.responsiveValue(context, 140),
                      height: Responsive.responsiveValue(context, 140),
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
                          onPressed: _showLoginOptionsSheetIOS,
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

  /// Android: 리뷰 반영 전과 동일한 마크업(§3 원칙 "Android 외형은 바꾸지
  /// 않는다").
  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
            const primaryBlue = Color(0xFF1963FF);
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
                        SizedBox(
                          height: Responsive.responsiveValue(context, 45),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/signup-intro');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.responsiveValue(context, 12),
                                ),
                              ),
                            ),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: Responsive.responsiveFontSize(
                                  context,
                                  16,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 12),
                        ),
                        SizedBox(
                          height: Responsive.responsiveValue(context, 45),
                          child: OutlinedButton(
                            onPressed: _showLoginOptionsSheetAndroid,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryBlue,
                              side: const BorderSide(
                                color: primaryBlue,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.responsiveValue(context, 12),
                                ),
                              ),
                            ),
                            child: Text(
                              '로그인',
                              style: TextStyle(
                                fontSize: Responsive.responsiveFontSize(
                                  context,
                                  16,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
