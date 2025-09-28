import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/top_curve_clipper.dart';
import 'package:after30/features/alarm/ui/widgets/alarm_header.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/common/navigationBar.dart';
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopCurveClipper(),
              child: Container(height: 300, color: const Color(0xFFFFEBEE)),
            ),
          ),
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
