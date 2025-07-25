import 'package:flutter/material.dart';
import 'package:after30/widgets/alarm_list/top_curve_clipper.dart';
import 'package:after30/widgets/alarm_list/alarm_header.dart';
import 'package:after30/widgets/alarm_list/alarm_content.dart';
import 'package:after30/widgets/alarm_list/alarm_bottom_navigation.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AlarmBottomNavigation(),
      body: Stack(
        children: [
          // 상단 곡선 배경
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopCurveClipper(),
              child: Container(
                height: 300,
                color: const Color(0xFFFFEBEE), // 연한 분홍
              ),
            ),
          ),
          // 내용
          SafeArea(
            child: Column(
              children: [const AlarmHeader(), const AlarmContent()],
            ),
          ),
        ],
      ),
    );
  }
}
