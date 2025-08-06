import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/widgets/home/home_app_bar.dart';
import 'package:after30/widgets/home/home_content.dart';

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
    }
  }

  Future<void> _logout() async {
    try {
      await UserApi.instance.logout();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (error) {
      print('로그아웃 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(onLogout: _logout),
      body: HomeContent(user: _user),
    );
  }
}
