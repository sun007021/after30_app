import 'package:flutter/material.dart';
import 'package:after30/widgets/alarm_list/top_curve_clipper.dart';
import 'package:after30/widgets/alarm_list/alarm_header.dart';
import 'package:after30/widgets/alarm_list/alarm_content.dart';
import 'package:after30/widgets/common/navigationBar.dart';
import 'package:android_intent_plus/android_intent.dart';

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
              children: [
                const AlarmHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        const intent = AndroidIntent(
                          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
                          arguments: <String, dynamic>{
                            'android.provider.extra.APP_PACKAGE':
                                'com.example.after30',
                          },
                        );
                        await intent.launch();
                      },
                      child: const Text('권한/팝업 설정 열기'),
                    ),
                  ),
                ),
                const AlarmContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
