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
          TargetPlatform.iOS: _ReducedMotionCupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: _ReducedMotionCupertinoPageTransitionsBuilder(),
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

/// iOS/macOS용 [CupertinoPageTransitionsBuilder]를 감싸되, 접근성 설정에서
/// "동작 줄이기"(`MediaQuery.disableAnimationsOf`)가 켜져 있으면 슬라이드
/// 대신 페이드로 대체한다(§4.3 모션 규칙).
///
/// [PageTransitionsTheme]는 [ThemeData] 생성 시점(=[AppTheme.build] 호출
/// 시점)에 한 번 만들어지고 이후 라우트 전환마다 재사용되므로, 실행 중에
/// 바뀌는 [MediaQuery] 값을 반영하려면 여기 [buildTransitions]처럼 매 전환마다
/// `context`를 통해 다시 읽어야 한다.
class _ReducedMotionCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ReducedMotionCupertinoPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _cupertino.buildTransitions(route, context, animation, secondaryAnimation, child);
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
