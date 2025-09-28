// 이 위젯은 login.dart(로그인 화면)에서 사용됩니다.
import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/after30logo.png', width: 120, height: 120),
        const SizedBox(height: 32),
        const Text(
          '식후 30분',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF191919),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '건강한 식습관을 위한 알림',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 64),
      ],
    );
  }
}
