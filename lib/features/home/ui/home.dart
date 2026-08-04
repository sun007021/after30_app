import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';

class HomePage extends StatefulWidget {
  final bool checkPhoneRegistration;

  const HomePage({super.key, this.checkPhoneRegistration = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    if (widget.checkPhoneRegistration) {
      _checkPhoneRegistration();
    }
  }

  Future<void> _checkPhoneRegistration() async {
    await PhoneRegisterDialog.checkAndShowIfNeeded(context);
  }

  Future<void> _loadUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      setState(() {
        _user = user;
      });
    } catch (error) {
      // 카카오 세션이 없는 이메일 로그인 등에서는 Kakao 사용자 정보가 없을 수 있음
      // 이 경우 앱 세션을 유지하고 홈을 그대로 보여준다.
      if (!mounted) return;
      setState(() {
        _user = null;
      });
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
