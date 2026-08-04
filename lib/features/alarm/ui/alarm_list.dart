import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/utils/responsive.dart';

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
            SizedBox(height: Responsive.responsiveHeight(context, 32)),
            Padding(
              padding: Responsive.responsivePadding(context, 24, 0),
              child: Text(
                '등록된 약',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 16)),
            // 본문 리스트는 스크롤되지만, 위의 헤더 Row는 고정
            const AlarmContent(),
          ],
        ),
      ),
    );
  }
}
