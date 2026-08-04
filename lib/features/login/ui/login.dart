import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/services/notifications/fcm_service.dart';
import 'package:after30/utils/responsive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Future<void> _handleKakaoLogin() async {
    try {
      bool kakaoTalkInstalled = await isKakaoTalkInstalled();
      OAuthToken? kakaoToken;
      if (kakaoTalkInstalled) {
        try {
          kakaoToken = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            return;
          }
          kakaoToken = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }

      // Kakao access token log (masked)
      final kakaoAccess = kakaoToken.accessToken;

      // ignore: avoid_print
      print('🔑 Kakao access token: $kakaoAccess');

      final backend = BackendAuthService();
      final resp = await backend.loginWithKakaoAccessToken(
        kakaoToken.accessToken,
      );

      // Backend access token log (masked)
      final beAccess = resp.accessToken;
      // ignore: avoid_print
      print('🔐 Backend access token: $beAccess');

      // 현재 사용자 ID 저장 및 알람 네임스페이스 설정
      final me = await UserApi.instance.me();
      final userId = me.id.toString();
      await UserStore.setCurrentUserId(userId);
      AlarmService.setCurrentUserId(userId);
      // 저장된 알람을 불러와 활성 항목 재스케줄
      await AlarmService().rescheduleAllActiveFromStorage();
      // 로그인 성공 시 FCM 토큰을 백엔드로 동기화
      await FcmService.syncTokenToBackend();

      _navigateToHome();
    } catch (e) {
      _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomePage(checkPhoneRegistration: true),
      ),
    );
  }

  void _showErrorDialog(String message) {
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

  Future<void> _showLoginOptionsSheet() async {
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
                            onPressed: _showLoginOptionsSheet,
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
