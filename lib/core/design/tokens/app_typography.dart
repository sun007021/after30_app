import 'package:flutter/widgets.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 타이포그래피 토큰.
///
/// 커스텀 폰트 없이 시스템 폰트(iOS: SF Pro/Apple SD Gothic Neo,
/// Android: Roboto/노토 산스)를 그대로 사용한다.
class AppTypography {
  AppTypography._();

  /// Large Title (34pt, bold). 최상위 탭 화면 헤더에 사용.
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: AppColors.label,
  );

  /// 내비게이션 바/섹션 타이틀 (17pt, semibold).
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.label,
  );

  /// 본문 (17pt, regular).
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.label,
  );

  /// 캡션/보조 설명 (13pt, regular).
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryLabel,
  );

  /// Dynamic Type 등으로 인해 레이아웃이 깨질 수 있는 자리에서 textScaler를
  /// 최대 1.3배로 제한한 위젯 서브트리를 만든다.
  /// `AppTypography.clampTextScale(child: ...)`처럼 감싸서 사용한다.
  static Widget clampTextScale({required Widget child}) {
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child);
  }
}
