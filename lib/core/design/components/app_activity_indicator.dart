import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';

/// 적응형 로딩 인디케이터.
/// iOS: [CupertinoActivityIndicator]. Android: 기존 [CircularProgressIndicator] 기본값.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({super.key, this.color, this.radius = 10});

  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoActivityIndicator(color: color, radius: radius);
    }
    // 기존 화면이 쓰던 기본 CircularProgressIndicator 그대로(36x36, 두께 4, 테마 색).
    // [radius]는 iOS 전용이다. 다른 크기/두께가 필요한 Android 호출부는 직접 쓴다.
    return CircularProgressIndicator(color: color);
  }
}
