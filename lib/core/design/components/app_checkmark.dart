import 'package:flutter/material.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';

/// 원형 체크 표시(약관 동의 목록 등에서 사용).
/// 플랫폼 간 외형 차이가 크지 않아 단일 디자인을 사용하되, iOS에서만
/// selection 햅틱을 재생한다.
class AppCheckmark extends StatelessWidget {
  const AppCheckmark({super.key, required this.checked, required this.onChanged, this.size = 22});

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () {
              AppHaptics.selection(context);
              onChanged!(!checked);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? AppColors.primary : Colors.transparent,
          border: Border.all(color: checked ? AppColors.primary : AppColors.secondaryLabel, width: 1.5),
        ),
        child: checked
            ? Icon(Icons.check, size: size * 0.65, color: Colors.white)
            : null,
      ),
    );
  }
}
