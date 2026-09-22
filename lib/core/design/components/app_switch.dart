import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 적응형 스위치.
/// iOS: [CupertinoSwitch](자체적으로 selection 햅틱을 재생하므로 여기서
/// 별도로 추가하지 않는다). Android: `switch_row.dart`가 쓰던 기존 [Switch]
/// 외형(기본 `materialTapTargetSize.padded`)을 그대로 재현한다.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.materialTapTargetSize = MaterialTapTargetSize.padded,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Android 전용. 기본값은 `switch_row.dart`와 동일한 `padded`이다.
  /// `my_info_widgets.dart`의 마케팅 동의 스위치처럼 촘촘한 레이아웃이
  /// 필요하면 `shrinkWrap`으로 재정의한다.
  final MaterialTapTargetSize materialTapTargetSize;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primaryAlt,
      inactiveThumbColor: Colors.grey[400],
      inactiveTrackColor: Colors.grey[300],
      materialTapTargetSize: materialTapTargetSize,
    );
  }
}
