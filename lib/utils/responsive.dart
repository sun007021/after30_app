import 'package:flutter/material.dart';

/// 반응형 디자인을 위한 유틸리티 클래스
class Responsive {
  /// 화면 너비에 따라 값을 조정
  /// 작은 화면(360px 이하): base * 0.85
  /// 중간 화면(360-400px): base * 0.95
  /// 큰 화면(400px 이상): base
  static double responsiveValue(BuildContext context, double base) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 360) {
      return base * 0.85;
    } else if (screenWidth <= 400) {
      return base * 0.95;
    }
    return base;
  }

  /// 화면 너비에 따라 폰트 크기 조정
  static double responsiveFontSize(BuildContext context, double base) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 360) {
      return base * 0.9;
    } else if (screenWidth <= 400) {
      return base * 0.95;
    }
    return base;
  }

  /// 화면 너비에 따라 패딩 조정
  static EdgeInsets responsivePadding(
    BuildContext context,
    double horizontal,
    double vertical,
  ) {
    final h = responsiveValue(context, horizontal);
    final v = responsiveValue(context, vertical);
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// 화면 너비에 따라 패딩 조정 (각 방향별)
  static EdgeInsets responsivePaddingLTRB(
    BuildContext context,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return EdgeInsets.fromLTRB(
      responsiveValue(context, left),
      responsiveValue(context, top),
      responsiveValue(context, right),
      responsiveValue(context, bottom),
    );
  }

  /// 화면 너비에 따라 마진 조정
  static EdgeInsets responsiveMargin(
    BuildContext context,
    double horizontal,
    double vertical,
  ) {
    final h = responsiveValue(context, horizontal);
    final v = responsiveValue(context, vertical);
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// 화면 너비에 따라 마진 조정 (각 방향별)
  static EdgeInsets responsiveMarginLTRB(
    BuildContext context,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return EdgeInsets.fromLTRB(
      responsiveValue(context, left),
      responsiveValue(context, top),
      responsiveValue(context, right),
      responsiveValue(context, bottom),
    );
  }

  /// 화면 너비에 따라 아이콘 크기 조정
  static double responsiveIconSize(BuildContext context, double base) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 360) {
      return base * 0.9;
    } else if (screenWidth <= 400) {
      return base * 0.95;
    }
    return base;
  }

  /// 화면 너비에 따라 SizedBox 높이 조정
  static double responsiveHeight(BuildContext context, double base) {
    return responsiveValue(context, base);
  }

  /// 화면 너비에 따라 SizedBox 너비 조정
  static double responsiveWidth(BuildContext context, double base) {
    return responsiveValue(context, base);
  }

  /// 작은 화면인지 확인
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <= 360;
  }

  /// 중간 화면인지 확인
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 360 && width <= 400;
  }

  /// 큰 화면인지 확인
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 400;
  }
}
