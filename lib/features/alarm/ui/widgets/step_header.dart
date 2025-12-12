import 'package:flutter/material.dart';

/// 약 등록 스텝 헤더 위젯
class StepHeader extends StatelessWidget {
  final int currentStep; // 1~3

  const StepHeader({super.key, required this.currentStep});

  Widget _circle(int step) {
    final isActive = currentStep == step;
    return Container(
      width: 34,
      height: 34,
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
          fontSize: 16,
          color: isActive ? Colors.white : const Color(0xFF020204),
        ),
      ),
    );
  }

  Widget _label(int step, String label) {
    final isActive = currentStep == step;
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: isActive ? const Color(0xFF235DFF) : const Color(0xFF020204),
      ),
    );
  }

  Widget _step(int step, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [_circle(step), const SizedBox(height: 6), _label(step, label)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _step(1, '약 정보 입력'),
          SizedBox(
            width: 64,
            height: 34,
            child: Center(
              child: Container(height: 2, color: const Color(0xFF020204)),
            ),
          ),
          _step(2, '복용 날짜 설정'),
          SizedBox(
            width: 64,
            height: 34,
            child: Center(
              child: Container(height: 2, color: const Color(0xFF020204)),
            ),
          ),
          _step(3, '복용 시간 설정'),
        ],
      ),
    );
  }
}
