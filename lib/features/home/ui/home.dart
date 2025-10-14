import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'package:after30/features/common/navigationBar.dart';

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
      if (!mounted) return;
      await AuthService.logout(context);
    }
  }

  // 상단 AppBar 제거로 더 이상 사용하지 않음

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeContent(user: _user),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 2),
    );
  }
}
