import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 앱 전역 [ThemeData]를 만든다.
///
/// 기존 colorScheme/Material 3 설정은 그대로 유지하고, 실행 플랫폼이
/// iOS/macOS일 때만 페이지 전환·스플래시·Cupertino 오버라이드를 iOS 26
/// 스펙(§4.3)에 맞게 바꾼다. Android(및 그 밖의 플랫폼)는 기존 화면 동작을
/// 그대로 유지하기 위해 `NoTransitionsPageTransitionsBuilder`와 기본
/// 리플(splash)을 그대로 쓴다.
///
/// 여기서는 위젯 테스트 플랫폼 주입과 무관하게(테마 자체가 실행 플랫폼에서
/// 한 번 만들어지는 값이므로) [defaultTargetPlatform]을 기준으로 분기한다.
/// 화면 위젯들의 분기는 `isCupertino(context)`를 쓰는 것이 원칙이다.
class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final isIOS =
        defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryTint),
      useMaterial3: true,
      splashFactory: isIOS ? NoSplash.splashFactory : null,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: NoTransitionsPageTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsPageTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: isIOS
          ? const CupertinoThemeData(primaryColor: AppColors.primary)
          : null,
    );
  }
}

/// 기존 화면들이 의존하던 "전환 없음" 페이지 전환(Android 등에서 유지).
/// 이전에는 `main.dart`에 정의되어 있었으나, 테마 구성 요소이므로
/// 디자인 시스템으로 옮겼다.
class NoTransitionsPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
