// 이 위젯은 login.dart(로그인 화면)에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/design.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/images/logowithname.svg',
          width: 120,
          height: 120,
        ),
        const SizedBox(height: 8),
        // iOS는 토큰 보조 라벨 색/크기, Android는 기존 값 유지
        Text(
          '건강한 식습관을 위한 알림',
          style: isCupertino(context)
              ? const TextStyle(fontSize: 17, color: AppColors.secondaryLabel)
              : const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 64),
      ],
    );
  }
}
