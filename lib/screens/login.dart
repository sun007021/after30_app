import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:after30/services/auth_api_service.dart';
import 'package:after30/models/login_response.dart';
import 'package:after30/services/token_provider.dart';
import 'package:after30/services/user_provider.dart';
import 'package:after30/services/secure_storage_service.dart';
import 'package:after30/widgets/common/error_dialog.dart';
import 'package:after30/screens/alarm_list.dart';
import 'package:after30/screens/home.dart';
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
      OAuthToken? kakaoToken;
      if (await isKakaoTalkInstalled()) {
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

      if (kakaoToken == null) {
        _showErrorDialog('카카오 로그인에 실패했습니다.');
        return;
      }

      // 백엔드에 카카오 토큰 전달
      final rawResponse = await AuthApiService.loginWithKakao(
        kakaoToken.accessToken,
      );
      final loginResponse = LoginResponse.fromJson(rawResponse);

      if (loginResponse.status == 'success') {
        // Provider, SecureStorage에 토큰/유저정보 저장
        final tokenProvider = Provider.of<TokenProvider>(
          context,
          listen: false,
        );
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await tokenProvider.saveTokens(
          accessToken: loginResponse.accessToken!,
          refreshToken: loginResponse.refreshToken!,
          expiresIn: loginResponse.expiresIn ?? 0,
          refreshExpiresIn: loginResponse.refreshExpiresIn ?? 0,
        );
        if (loginResponse.user != null) {
          await userProvider.saveUser(
            userId: loginResponse.user!.userId,
            userName: loginResponse.user!.name,
          );
        }

        // 신규 유저 분기(온보딩 등)
        if (loginResponse.isNewUser) {
          _showInfoDialog('환영합니다! 회원가입이 완료되었습니다.');
        } else {
          _navigateToAlarm();
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: '로그인 실패',
            message: loginResponse.message ?? '로그인에 실패했습니다.',
            detail: loginResponse.errorDetail,
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) =>
            const ErrorDialog(title: '네트워크 오류', message: '서버와의 통신에 실패했습니다.'),
      );
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

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('안내'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToAlarm();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ErrorDialog(title: '로그인 실패', message: message);
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
                  onPressed: _navigateToAlarm,
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
