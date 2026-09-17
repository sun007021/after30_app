import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// 리퀴드 글래스 근사 표면(§4.1).
///
/// 내비게이션 레이어(탭바, 내비게이션 바 버튼, 플로팅 CTA, 시트/팝오버
/// 배경)에만 사용한다. 목록, 카드 같은 콘텐츠 레이어는 불투명하게 두고
/// 글래스 위에 글래스를 겹치지 않는다.
///
/// `MediaQuery.highContrastOf(context)`가 켜져 있으면 투명도를 줄이는 대신
/// 불투명 배경으로 대체한다(접근성).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape,
    this.blurSigma = 24,
    this.tintOpacity = 0.62,
    this.padding,
  });

  final Widget child;

  /// 사각 곡률이 필요한 경우 사용(예: 배경 클리핑용).
  final BorderRadius? borderRadius;

  /// 연속 곡률 등 커스텀 shape가 필요한 경우 사용. 지정 시 [borderRadius]는
  /// 무시된다.
  final OutlinedBorder? shape;

  final double blurSigma;
  final double tintOpacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final defaultRadius = borderRadius ?? AppRadius.borderRadius(AppRadius.lg);
    // 글래스는 내비게이션 레이어(iOS) 전용이므로 기본 shape도 연속 곡률로
    // 맞춘다. Android에서 실수로 쓰이더라도 사각 곡률로 안전하게 대체된다.
    final resolvedShape = shape ??
        (isCupertino(context)
            ? RoundedSuperellipseBorder(borderRadius: defaultRadius)
            : RoundedRectangleBorder(borderRadius: defaultRadius));

    if (highContrast) {
      // 고대비 모드: 블러/반투명 대신 불투명 배경으로 대체한다.
      return Material(
        color: AppColors.surface,
        shape: resolvedShape,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
    }

    return _GlassClip(
      shape: resolvedShape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: resolvedShape.copyWith(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 0.5),
            ),
            color: AppColors.glassTint.withValues(alpha: tintOpacity),
            shadows: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// [BackdropFilter]가 [shape] 모양대로 클리핑되도록 감싸는 도우미.
/// `RoundedSuperellipseBorder`처럼 연속 곡률 shape가 오더라도
/// `ShapeBorder.getOuterPath`를 이용해 그대로 클리핑한다.
class _GlassClip extends StatelessWidget {
  const _GlassClip({required this.shape, required this.child});

  final OutlinedBorder shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ShapeBorderClipper(shape: shape),
      child: child,
    );
  }
}

class _ShapeBorderClipper extends CustomClipper<Path> {
  _ShapeBorderClipper({required this.shape});

  final OutlinedBorder shape;

  @override
  Path getClip(Size size) => shape.getOuterPath(Offset.zero & size);

  @override
  bool shouldReclip(covariant _ShapeBorderClipper oldClipper) => oldClipper.shape != shape;
}
