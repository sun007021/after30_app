import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 캘린더 월 헤더 위젯
class CalendarMonthHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final GlobalKey? monthHeaderKey;

  /// 제목(연/월 텍스트)을 탭했을 때 호출된다. 지정하면 연/월 점프 피커를
  /// 띄우는 용도로 쓸 수 있다(§6 W7). 지정하지 않으면 탭해도 아무 일도
  /// 일어나지 않는다(기존 동작).
  final VoidCallback? onTitleTap;

  const CalendarMonthHeader({
    super.key,
    required this.focusedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.monthHeaderKey,
    this.onTitleTap,
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
        GestureDetector(
          onTap: onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            '${focusedDay.year}년 ${focusedDay.month.toString().padLeft(2, '0')}월',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            key: monthHeaderKey,
          ),
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



