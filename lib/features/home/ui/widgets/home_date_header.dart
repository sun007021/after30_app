import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';
import 'package:after30/utils/responsive.dart';

/// 홈 화면의 날짜 선택 헤더 위젯
class HomeDateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  const HomeDateHeader({
    super.key,
    required this.selectedDate,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPreviousDay,
          icon: Opacity(
            // 범위(2000~2100)의 끝에서는 화살표를 비활성 상태로 보이게 한다.
            opacity: onPreviousDay == null ? 0.3 : 1.0,
            child: SvgPicture.asset(
              'assets/images/chevron_left.svg',
              width: Responsive.responsiveIconSize(context, 8),
              height: Responsive.responsiveIconSize(context, 14),
            ),
          ),
        ),
        Text(
          formatKoreanDate(selectedDate),
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: onNextDay,
          icon: Opacity(
            opacity: onNextDay == null ? 0.3 : 1.0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
              child: SvgPicture.asset(
                'assets/images/chevron_left.svg',
                width: Responsive.responsiveIconSize(context, 8),
                height: Responsive.responsiveIconSize(context, 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
