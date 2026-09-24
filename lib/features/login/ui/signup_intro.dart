import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/core/auth/session_bootstrapper.dart';
import 'package:after30/utils/responsive.dart';

class SignupIntroPage extends StatefulWidget {
  const SignupIntroPage({super.key});

  @override
  State<SignupIntroPage> createState() => _SignupIntroPageState();
}

class _SignupIntroPageState extends State<SignupIntroPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);

  Future<void> _handleKakaoLogin() async {
    try {
      // 토큰 저장 → 사용자 ID 통합(백엔드 ID 기준) → 알람 네임스페이스
      // 마이그레이션 → 재스케줄 → FCM 동기화 → 셸 진입까지는
      // SessionBootstrapper가 공통으로 처리한다(plan §6 W3a 1항). 예전에는
      // 이 화면이 카카오 회원 ID(`UserApi.instance.me().id`)를 직접
      // 저장해서, 제공자가 늘어나면 사용자 ID 기준이 달라지는 문제가
      // 있었다.
      await SessionBootstrapper.completeLogin(
        context,
        KakaoAuthProviderClient(),
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
                  padding: Responsive.responsivePaddingLTRB(
                    context,
                    24,
                    32,
                    24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: Responsive.responsiveHeight(context, 8)),
                      Center(
                        child: Text(
                          '간편하게 SNS로 가입하세요',
                          style: TextStyle(
                            color: const Color(0xFF111111),
                            fontSize: Responsive.responsiveFontSize(
                              context,
                              13,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 20),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 48),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Responsive.responsiveValue(context, 12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleKakaoLogin,
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
                                    Text(
                                      '카카오로 시작하기',
                                      style: TextStyle(
                                        color: const Color(0xFF191919),
                                        fontWeight: FontWeight.w700,
                                        fontSize: Responsive.responsiveFontSize(
                                          context,
                                          16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 44),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: const Color(0xFFBBBBBB)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.responsiveValue(
                                context,
                                8,
                              ),
                            ),
                            child: Text(
                              '또는',
                              style: TextStyle(
                                color: const Color(0xFF999999),
                                fontSize: Responsive.responsiveFontSize(
                                  context,
                                  14,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: const Color(0xFFBBBBBB)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 48),
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
                              borderRadius: BorderRadius.circular(
                                Responsive.responsiveValue(context, 12),
                              ),
                            ),
                          ),
                          child: Text(
                            '이메일로 가입하기',
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
      padding: Responsive.responsivePaddingLTRB(context, 24, 5, 24, 55),
      decoration: const BoxDecoration(color: _primaryBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.zero,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: SvgPicture.asset(
                    'assets/images/signupicon/backicon.svg',
                    width: Responsive.responsiveValue(context, 18),
                    height: Responsive.responsiveValue(context, 16),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 28)),
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.responsiveValue(context, 12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '식후 30분',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.responsiveFontSize(context, 30),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: Responsive.responsiveValue(context, 10)),
                // 제목 오른쪽 로고
                SvgPicture.asset(
                  'assets/images/signupicon/namelogo.svg',
                  width: Responsive.responsiveIconSize(context, 24),
                  height: Responsive.responsiveIconSize(context, 24),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 9)),
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.responsiveValue(context, 12),
            ),
            child: Row(
              children: [
                Text(
                  '회원가입',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.responsiveFontSize(context, 15),
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
