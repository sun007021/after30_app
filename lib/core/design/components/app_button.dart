import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';
import 'package:after30/core/design/tokens/app_radius.dart';
import 'package:after30/core/design/components/glass_surface.dart';
import 'package:after30/utils/responsive.dart';

/// [AppButton] 색상/강조 변형.
enum AppButtonVariant {
  /// 브랜드 컬러로 채워진 주요 버튼.
  filled,

  /// 브랜드 컬러 12% 배경의 보조 버튼.
  tinted,

  /// 테두리만 있는 버튼.
  outline,

  /// 배경 없는 텍스트 버튼.
  text,

  /// 글래스 표면 위에 놓이는 버튼(내비게이션 레이어 전용).
  glass,
}

/// [AppButton] 크기.
enum AppButtonSize {
  /// 높이 50, 주요 CTA.
  large,

  /// 높이 44, 보조 버튼.
  medium,
}

/// 플랫폼 적응형 버튼.
///
/// iOS: 캡슐 모양, 눌림 시 투명도 0.7 + selection 햅틱, 리플 없음.
/// Android: 기존 화면들이 쓰던 [ElevatedButton]/[OutlinedButton]/[TextButton]
/// 스타일(곡률 12, 리플 있음)을 그대로 재현한다.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.large,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;

  /// true면 부모 너비만큼 확장(기존 버튼들의 기본 동작).
  final bool expand;
  final Widget? icon;

  bool get _disabled => onPressed == null || loading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  double get _height => widget.size == AppButtonSize.large ? 50 : 44;

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 눌린 상태에서 버튼이 비활성화되면(onPressed가 null이 되면) 눌림
    // 투명도가 그대로 남아있을 수 있으므로 초기화한다.
    if (widget.onPressed == null && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semanticLabel = widget.loading ? '${widget.label}, 로딩 중' : widget.label;
    return Semantics(
      button: true,
      enabled: !widget._disabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: isCupertino(context) ? _buildCupertino(context) : _buildMaterial(context),
    );
  }

  // ---------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------

  Widget _buildCupertino(BuildContext context) {
    final colors = _cupertinoColors();
    final child = _content(colors.foreground);

    Widget button = AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: widget._disabled && !widget.loading ? 0.4 : (_pressed ? 0.7 : 1.0),
      child: Container(
        height: _height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: widget.variant == AppButtonVariant.glass
            ? null
            : ShapeDecoration(
                color: colors.background,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(_height / 2),
                  side: colors.borderSide ?? BorderSide.none,
                ),
              ),
        child: child,
      ),
    );

    if (widget.variant == AppButtonVariant.glass) {
      button = GlassSurface(
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(_height / 2)),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(height: _height, child: Center(child: child)),
      );
    }

    if (widget.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // onTapDown/onTapCancel/onTapUp는 disabled 여부와 무관하게 항상 등록해
    // 둔다. 셋을 모두 null로 두면 GestureDetector가 TapGestureRecognizer
    // 자체를 제거하는데, 누르고 있는 도중에 disabled로 바뀌면 눌려 있던
    // 인식기가 빌드 도중 강제로 dispose되면서 예전 onTapCancel 콜백이
    // "spontaneous cancel"로 동기 호출되어 "setState() called during
    // build" 예외가 난다. disabled일 때는 opacity 계산에서 0.4가 항상
    // 우선하므로 _pressed가 true여도 눌림 효과가 보이지 않아 안전하다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget._disabled
          ? null
          : () {
              AppHaptics.buttonPress(context);
              widget.onPressed?.call();
            },
      child: button,
    );
  }

  ({Color background, Color foreground, BorderSide? borderSide}) _cupertinoColors() {
    switch (widget.variant) {
      case AppButtonVariant.filled:
        return (background: AppColors.primary, foreground: Colors.white, borderSide: null);
      case AppButtonVariant.tinted:
        return (
          background: AppColors.primary.withValues(alpha: 0.12),
          foreground: AppColors.primary,
          borderSide: null,
        );
      case AppButtonVariant.outline:
        return (
          background: Colors.transparent,
          foreground: AppColors.primary,
          borderSide: const BorderSide(color: AppColors.primary),
        );
      case AppButtonVariant.text:
        return (background: Colors.transparent, foreground: AppColors.primary, borderSide: null);
      case AppButtonVariant.glass:
        return (background: Colors.transparent, foreground: AppColors.label, borderSide: null);
    }
  }

  // ---------------------------------------------------------------------
  // Android(기존 화면 외형 재현)
  // ---------------------------------------------------------------------

  Widget _buildMaterial(BuildContext context) {
    final child = _content(_materialForegroundColor(), fontSize: Responsive.responsiveFontSize(context, 16));
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm));
    final minSize = Size(0, _height);

    Widget button;
    switch (widget.variant) {
      case AppButtonVariant.filled:
      case AppButtonVariant.glass:
        button = ElevatedButton(
          onPressed: widget._disabled ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            elevation: 0,
            shape: shape,
            minimumSize: minSize,
          ),
          child: child,
        );
        break;
      case AppButtonVariant.tinted:
        button = ElevatedButton(
          onPressed: widget._disabled ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
            elevation: 0,
            shape: shape,
            minimumSize: minSize,
          ),
          child: child,
        );
        break;
      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: widget._disabled ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: shape,
            minimumSize: minSize,
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: widget._disabled ? null : widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            shape: shape,
            minimumSize: minSize,
          ),
          child: child,
        );
        break;
    }

    if (widget.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Color _materialForegroundColor() {
    switch (widget.variant) {
      case AppButtonVariant.filled:
      case AppButtonVariant.glass:
        return Colors.white;
      case AppButtonVariant.tinted:
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppColors.primary;
    }
  }

  Widget _content(Color foreground, {double fontSize = 16}) {
    if (widget.loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: isCupertino(context)
            ? CupertinoActivityIndicator(color: foreground)
            : CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.icon!,
          const SizedBox(width: 8),
          Text(widget.label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: foreground)),
        ],
      );
    }
    return Text(
      widget.label,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: foreground),
    );
  }
}
