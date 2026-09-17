import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';

/// 곡률 토큰.
///
/// iOS 분기에서는 연속 곡률([RoundedSuperellipseBorder])을, Android
/// 분기에서는 기존 [RoundedRectangleBorder]를 사용한다.
class AppRadius {
  AppRadius._();

  /// 작은 배지, 태그.
  static const double xs = 8;

  /// 텍스트필드, 작은 버튼.
  static const double sm = 12;

  /// 목록 셀 그룹(inset grouped).
  static const double md = 16;

  /// 카드.
  static const double lg = 22;

  /// 시트 상단, 알럿.
  static const double xl = 28;

  /// 캡슐(알약 모양) 곡률로 쓸 큰 값. 실제로는 높이/2를 그대로 넘기는 것이
  /// 더 정확하지만, 상수가 필요한 자리에서는 이 값을 상한으로 사용한다.
  static const double capsule = 999;

  /// 동심원 규칙: 바깥 곡률에서 안쪽 여백만큼을 뺀 안쪽 곡률을 계산한다.
  /// 결과가 음수가 되지 않도록 0으로 하한을 둔다.
  static double concentric(double outer, double padding) {
    final inner = outer - padding;
    return inner < 0 ? 0 : inner;
  }

  /// 플랫폼에 맞는 [OutlinedBorder]를 반환한다.
  /// iOS: [RoundedSuperellipseBorder](연속 곡률)
  /// Android: [RoundedRectangleBorder]
  static OutlinedBorder shape(
    BuildContext context,
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    final r = BorderRadius.circular(radius);
    if (isCupertino(context)) {
      return RoundedSuperellipseBorder(borderRadius: r, side: side);
    }
    return RoundedRectangleBorder(borderRadius: r, side: side);
  }

  /// [BoxDecoration] 등에 바로 쓸 수 있는 [BorderRadius].
  /// (연속 곡률은 `ShapeBorder`로만 표현 가능하므로, `Container.decoration`
  /// 자리에서는 [ClipRSuperellipse]와 함께 사용해야 진짜 연속 곡률이 된다.
  /// 이 헬퍼는 일반 사각 곡률이 필요한 자리를 위한 값이다.)
  static BorderRadius borderRadius(double radius) => BorderRadius.circular(radius);
}
