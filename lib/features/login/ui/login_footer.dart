// 이 위젯은 login.dart(로그인 화면)에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          '시작하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
          style: isCupertino(context)
              ? const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)
              : const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
