import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 캘린더 월 헤더 위젯
class CalendarMonthHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final GlobalKey? monthHeaderKey;

  const CalendarMonthHeader({
    super.key,
    required this.focusedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.monthHeaderKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/images/chevron_left.svg',
            width: 8,
            height: 14,
          ),
          onPressed: onPreviousMonth,
        ),
        Text(
          '${focusedDay.year}년 ${focusedDay.month.toString().padLeft(2, '0')}월',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          key: monthHeaderKey,
        ),
        IconButton(
          icon: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: SvgPicture.asset(
              'assets/images/chevron_left.svg',
              width: 8,
              height: 14,
            ),
          ),
          onPressed: onNextMonth,
        ),
      ],
    );
  }
}


