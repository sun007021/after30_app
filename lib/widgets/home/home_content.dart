import 'package:flutter/material.dart';
import 'package:after30/widgets/home/user_profile.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class HomeContent extends StatelessWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home, size: 100, color: Colors.yellow),
          const SizedBox(height: 32),
          Text(
            '환영합니다!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          UserProfile(user: user),
          const SizedBox(height: 32),
          const Text(
            '식후 30분 앱에 오신 것을 환영합니다!',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '건강한 식습관을 위한 알림을 받아보세요.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
