import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/screens/alarm_list.dart';
import 'package:after30/widgets/login/login_header.dart';
import 'package:after30/widgets/login/kakao_login_button.dart';
import 'package:after30/widgets/login/login_footer.dart';

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
      print('카카오 로그인 시작');

      // 카카오톡 설치 여부 확인
      bool kakaoTalkInstalled = await isKakaoTalkInstalled();
      print('카카오톡 설치 여부: $kakaoTalkInstalled');

      OAuthToken? kakaoToken;

      if (kakaoTalkInstalled) {
        try {
          print('카카오톡으로 로그인 시도');
          kakaoToken = await UserApi.instance.loginWithKakaoTalk();
          print('카카오톡 로그인 성공');
        } catch (error) {
          print('카카오톡 로그인 실패: $error');
          if (error is PlatformException && error.code == 'CANCELED') {
            print('사용자가 로그인을 취소함');
            setState(() {
              _isLoading = false;
            });
            return;
          }
          // 카카오톡 로그인 실패 시 웹 로그인으로 전환
          try {
            print('웹 로그인으로 전환');
            kakaoToken = await UserApi.instance.loginWithKakaoAccount();
            print('웹 로그인 성공');
          } catch (webError) {
            print('웹 로그인도 실패: $webError');
            throw webError;
          }
        }
      } else {
        try {
          print('웹 로그인 시도');
          kakaoToken = await UserApi.instance.loginWithKakaoAccount();
          print('웹 로그인 성공');
        } catch (error) {
          print('웹 로그인 실패: $error');
          throw error;
        }
      }

      if (kakaoToken == null) {
        print('카카오 토큰이 null');
        _showErrorDialog('카카오 로그인에 실패했습니다.');
        return;
      }

      print('로그인 성공, 토큰: ${kakaoToken.accessToken}');

      // 카카오 로그인 성공 시 바로 홈 화면으로 이동
      _navigateToAlarm();
    } catch (e) {
      print('로그인 중 오류 발생: $e');
      _showErrorDialog('로그인 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToAlarm() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AlarmPage()),
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
