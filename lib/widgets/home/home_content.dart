import 'package:flutter/material.dart';
import 'package:after30/widgets/home/user_profile.dart';
import 'package:after30/widgets/common/navigationBar.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/services/alarm_service.dart';
import 'package:after30/models/medicine_alarm.dart';

class HomeContent extends StatelessWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  void _testFullscreenAlarm(BuildContext context) {
    // 테스트용 알람 데이터
    final testAlarm = MedicineAlarm(
      name: '비염약',
      times: [const TimeOfDay(hour: 12, minute: 30)],
      days: ['월'],
    );

    AlarmService.showFullscreenAlarm(
      context,
      testAlarm,
      const TimeOfDay(hour: 12, minute: 30),
      '월',
      notificationId: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
            const SizedBox(height: 32),
            // 테스트 버튼 추가
            ElevatedButton(
              onPressed: () => _testFullscreenAlarm(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('전체화면 알림 테스트'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }
}
