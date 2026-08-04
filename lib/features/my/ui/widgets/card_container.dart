import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

/// 재사용 가능한 카드 컨테이너 위젯
class CardContainer extends StatelessWidget {
  final Widget child;

  const CardContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 5),
        ),
      ),
      child: Padding(
        padding: Responsive.responsivePadding(context, 16, 0),
        child: child,
      ),
    );
  }
}
