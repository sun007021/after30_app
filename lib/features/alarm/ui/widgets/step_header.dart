import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

/// 약 등록 스텝 헤더 위젯
class StepHeader extends StatelessWidget {
  final int currentStep; // 1~3

  const StepHeader({super.key, required this.currentStep});

  Widget _circle(BuildContext context, int step) {
    final isActive = currentStep == step;
    return Container(
      width: Responsive.responsiveValue(context, 34),
      height: Responsive.responsiveValue(context, 34),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF235DFF) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF235DFF) : const Color(0xFF020204),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: Responsive.responsiveFontSize(context, 16),
          color: isActive ? Colors.white : const Color(0xFF020204),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, int step, String label) {
    final isActive = currentStep == step;
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 12),
        color: isActive ? const Color(0xFF235DFF) : const Color(0xFF020204),
      ),
    );
  }

  Widget _step(BuildContext context, int step, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(context, step),
        SizedBox(height: Responsive.responsiveHeight(context, 6)),
        _label(context, step, label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: Responsive.responsiveHeight(context, 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _step(context, 1, '약 정보 입력'),
          SizedBox(
            width: Responsive.responsiveValue(context, 64),
            height: Responsive.responsiveValue(context, 34),
            child: Center(
              child: Container(height: 2, color: const Color(0xFF020204)),
            ),
          ),
          _step(context, 2, '복용 날짜 설정'),
          SizedBox(
            width: Responsive.responsiveValue(context, 64),
            height: Responsive.responsiveValue(context, 34),
            child: Center(
              child: Container(height: 2, color: const Color(0xFF020204)),
            ),
          ),
          _step(context, 3, '복용 시간 설정'),
        ],
      ),
    );
  }
}
