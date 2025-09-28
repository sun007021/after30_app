import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/login/ui/login_header.dart';
import 'package:after30/features/login/ui/kakao_login_button.dart';
import 'package:after30/features/login/ui/login_footer.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool kakaoTalkInstalled = await isKakaoTalkInstalled();
      OAuthToken? kakaoToken;
      if (kakaoTalkInstalled) {
        try {
          kakaoToken = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            setState(() {
              _isLoading = false;
            });
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

      _navigateToHome();
    } catch (e) {
      _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LoginHeader(),
                KakaoLoginButton(
                  isLoading: _isLoading,
                  onPressed: _handleKakaoLogin,
                ),
                const LoginFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
