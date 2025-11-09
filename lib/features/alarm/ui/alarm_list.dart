import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/common/navigationBar.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 64),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                '등록된 약',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            // 본문 리스트 및 상단 우측 'NFC 관리하기'는 AlarmContent에서 렌더링
            const AlarmContent(),
          ],
        ),
      ),
    );
  }
}
