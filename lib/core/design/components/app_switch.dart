import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';

/// 적응형 스위치.
/// iOS: [CupertinoSwitch] + selection 햅틱. Android: 기존 [Switch] 외형 유지.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: onChanged == null
            ? null
            : (v) {
                AppHaptics.selection(context);
                onChanged!(v);
              },
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primaryAlt,
      inactiveThumbColor: Colors.grey[400],
      inactiveTrackColor: Colors.grey[300],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
