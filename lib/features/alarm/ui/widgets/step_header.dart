import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

/// 약 등록 / 가족 초대 공통 스텝 헤더 위젯
class StepHeader extends StatelessWidget {
  final int currentStep; // 1~3
  final String step1Label;
  final String step2Label;
  final String step3Label;

  const StepHeader({
    super.key,
    required this.currentStep,
    this.step1Label = '약 정보 입력',
    this.step2Label = '복용 날짜 설정',
    this.step3Label = '복용 시간 설정',
  });

  static const _activeColor = Color(0xFF235DFF);
  static const _inactiveColor = Color(0xFF020204);

  bool get _showLabels =>
      step1Label.isNotEmpty || step2Label.isNotEmpty || step3Label.isNotEmpty;

  Widget _circle(BuildContext context, int step) {
    final isActive = currentStep == step;
    final size = Responsive.responsiveValue(context, 32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? _activeColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? _activeColor : _inactiveColor,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: Responsive.responsiveFontSize(context, 15),
          color: isActive ? Colors.white : _inactiveColor,
          height: 1,
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
        color: isActive ? _activeColor : _inactiveColor,
      ),
    );
  }

  Widget _step(BuildContext context, int step, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circle(context, step),
        if (_showLabels && label.isNotEmpty) ...[
          SizedBox(height: Responsive.responsiveHeight(context, 6)),
          _label(context, step, label),
        ],
      ],
    );
  }

  Widget _connector(BuildContext context) {
    final circleSize = Responsive.responsiveValue(context, 32);
    final gap = Responsive.responsiveValue(context, 10);
    return SizedBox(
      width: Responsive.responsiveValue(context, 100),
      height: circleSize,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gap),
        child: Center(
          child: Container(height: 1.5, color: _inactiveColor),
        ),
      ),
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
        crossAxisAlignment:
            _showLabels ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _step(context, 1, step1Label),
          _connector(context),
          _step(context, 2, step2Label),
          _connector(context),
          _step(context, 3, step3Label),
        ],
      ),
    );
  }
}
