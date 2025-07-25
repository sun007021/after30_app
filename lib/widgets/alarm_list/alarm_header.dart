// 이 위젯은 alarm_list.dart, add_alarm.dart(알람 목록/추가 화면)에서 사용됩니다.
import 'package:flutter/material.dart';

class AlarmHeader extends StatelessWidget {
  final bool showBackButton;
  const AlarmHeader({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 바
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '약 챙겨먹자!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
