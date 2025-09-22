import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/widgets/home/home_app_bar.dart';
import 'package:after30/widgets/home/home_content.dart';
import 'package:after30/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      setState(() {
        _user = user;
      });
    } catch (error) {
      print('사용자 정보 로드 실패: $error');
      // 카카오 토큰이 없거나 무효인 경우, 세션 정리 후 로그인 화면으로 이동
      if (!mounted) return;
      await AuthService.logout(context);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(onLogout: _logout),
      body: HomeContent(user: _user),
    );
  }
}
