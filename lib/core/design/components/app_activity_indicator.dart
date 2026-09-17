import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 적응형 로딩 인디케이터.
/// iOS: [CupertinoActivityIndicator]. Android: 기존 [CircularProgressIndicator].
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({super.key, this.color, this.radius = 10});

  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoActivityIndicator(color: color, radius: radius);
    }
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: color ?? AppColors.primary,
      ),
    );
  }
}
