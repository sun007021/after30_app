import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/home/ui/home.dart';

class SignupIntroPage extends StatefulWidget {
  const SignupIntroPage({super.key});

  @override
  State<SignupIntroPage> createState() => _SignupIntroPageState();
}

class _SignupIntroPageState extends State<SignupIntroPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);

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

      final backend = BackendAuthService();
      await backend.loginWithKakaoAccessToken(kakaoToken.accessToken);

      final me = await UserApi.instance.me();
      final userId = me.id.toString();
      await UserStore.setCurrentUserId(userId);
      AlarmService.setCurrentUserId(userId);
      await AlarmService().rescheduleAllActiveFromStorage();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('로그인 실패'),
            content: Text('카카오 로그인 중 오류가 발생했습니다: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          '간편하게 SNS로 가입하세요',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleKakaoLogin,
                              child: Ink.image(
                                image: const AssetImage(
                                  'assets/images/kakao_login_medium_wide.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFBBBBBB)),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '또는',
                              style: TextStyle(color: Color(0xFF999999)),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFBBBBBB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/signup-terms');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111111),
                            side: const BorderSide(
                              color: Color(0xFF111111),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '이메일로 가입하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 5, 24, 50),
      decoration: const BoxDecoration(color: _primaryBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: SvgPicture.asset(
                  'assets/images/signupicon/backicon.svg',
                  width: 18,
                  height: 16,
                ),
                padding: EdgeInsets.only(left: 12),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 12),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '식후 30분',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                // 제목 오른쪽 로고
                SvgPicture.asset(
                  'assets/images/signupicon/namelogo.svg',
                  width: 24,
                  height: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Text(
                  '회원가입',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
