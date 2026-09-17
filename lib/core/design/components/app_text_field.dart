import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';
import 'package:after30/core/design/components/keyboard_done_bar.dart';
import 'package:after30/utils/responsive.dart';

/// 플랫폼 적응형 텍스트필드.
///
/// iOS: 배경 `#F2F2F7` 계열, 곡률 sm, 포커스 시 브랜드 블루 테두리, 입력값이
/// 있을 때 clear 버튼. 숫자/전화 패드일 때는 루트 [Overlay] 위에
/// [KeyboardDoneBar]를 띄워 키보드 바로 위에 "완료" 액세서리를 보여준다
/// (포커스를 잃거나 위젯이 사라지면 자동으로 정리된다).
/// Android: 기존 화면들이 쓰던 [TextField] 외형을 그대로 재현한다. 기존
/// 화면의 `InputDecoration`을 그대로 유지해야 한다면 [materialDecoration]에
/// 전체 데코레이션을 넘길 수 있다.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.showObscureToggle = false,
    this.autofillHints,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.readOnly = false,
    this.onSubmitted,
    this.onChanged,
    this.onEditingComplete,
    this.showKeyboardDoneBar,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.prefix,
    this.suffix,
    this.materialDecoration,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;

  /// true면 obscureText를 눈 모양 아이콘으로 토글할 수 있다.
  final bool showObscureToggle;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  /// iOS 숫자/전화 패드 위에 "완료" 액세서리 바를 표시할지 여부. `null`이면
  /// 숫자/전화 패드([TextInputType.number]/[TextInputType.phone] 계열,
  /// `numberWithOptions`의 decimal/signed 옵션 포함)일 때 자동으로 true로
  /// 취급한다.
  final bool? showKeyboardDoneBar;
  final FocusNode? focusNode;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextStyle? style;

  /// 입력창 앞/뒤에 붙는 위젯(예: 국가 코드, 단위 텍스트).
  final Widget? prefix;
  final Widget? suffix;

  /// Android 전용: 지정하면 label/placeholder/errorText 등을 무시하고 이
  /// [InputDecoration]을 그대로 사용한다. 기존 화면의 정확한 외형을 유지한
  /// 채 마이그레이션해야 할 때 사용한다.
  final InputDecoration? materialDecoration;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _ownsFocusNode = false;
  bool _ownsController = false;
  bool _obscure = true;
  bool _focused = false;
  OverlayEntry? _doneBarEntry;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _attachFocusNode(widget.focusNode);
    _attachController(widget.controller);
  }

  void _attachFocusNode(FocusNode? external) {
    _ownsFocusNode = external == null;
    _focusNode = external ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  void _attachController(TextEditingController? external) {
    _ownsController = external == null;
    _controller = external ?? TextEditingController();
    _controller.addListener(_handleTextChange);
  }

  void _detachController() {
    _controller.removeListener(_handleTextChange);
    if (_ownsController) _controller.dispose();
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }
    if (widget.controller != oldWidget.controller) {
      _detachController();
      _attachController(widget.controller);
    }
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
    _updateDoneBarOverlay();
  }

  void _handleTextChange() {
    // clear 버튼 표시 여부 갱신을 위해 리빌드만 트리거한다.
    setState(() {});
  }

  @override
  void dispose() {
    _removeDoneBarOverlay();
    _detachFocusNode();
    _detachController();
    super.dispose();
  }

  /// [TextInputType.index]로 비교해 `numberWithOptions(decimal/signed)`처럼
  /// 옵션이 붙은 숫자 키보드도 모두 숫자 패드로 인식한다(`==` 비교는
  /// signed/decimal 옵션까지 비교해 버려서 놓치기 쉽다).
  bool get _isNumericPad {
    final index = widget.keyboardType?.index;
    return index == TextInputType.number.index || index == TextInputType.phone.index;
  }

  bool get _effectiveShowDoneBar => widget.showKeyboardDoneBar ?? _isNumericPad;

  void _updateDoneBarOverlay() {
    final shouldShow = isCupertino(context) && _focused && _effectiveShowDoneBar && _isNumericPad;
    if (shouldShow) {
      if (_doneBarEntry == null) {
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        if (overlay == null) return;
        _doneBarEntry = OverlayEntry(
          builder: (ctx) => Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            child: KeyboardDoneBar(visible: true, onDone: () => _focusNode.unfocus()),
          ),
        );
        overlay.insert(_doneBarEntry!);
      }
    } else {
      _removeDoneBarOverlay();
    }
  }

  void _removeDoneBarOverlay() {
    _doneBarEntry?.remove();
    _doneBarEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  // ---------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------

  Widget _buildCupertino(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? AppColors.destructive
        : (_focused ? AppColors.primary : Colors.transparent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
          const SizedBox(height: 6),
        ],
        Container(
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.borderRadius(AppRadius.sm),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.prefix != null) ...[widget.prefix!, const SizedBox(width: 8)],
              Expanded(
                child: CupertinoTextField.borderless(
                  controller: _controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText && _obscure,
                  placeholder: widget.placeholder,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  inputFormatters: widget.inputFormatters,
                  maxLength: widget.maxLength,
                  maxLines: widget.maxLines,
                  readOnly: widget.readOnly,
                  enabled: widget.enabled,
                  autofillHints: widget.autofillHints,
                  autofocus: widget.autofocus,
                  textCapitalization: widget.textCapitalization,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  onEditingComplete: widget.onEditingComplete,
                  padding: EdgeInsets.zero,
                  style: widget.style ?? const TextStyle(fontSize: 17, color: AppColors.label),
                  placeholderStyle: const TextStyle(fontSize: 17, color: AppColors.secondaryLabel),
                ),
              ),
              if (widget.showObscureToggle)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                    size: 18,
                    color: AppColors.secondaryLabel,
                  ),
                )
              else if (_controller.text.isNotEmpty && !widget.readOnly)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 18, color: AppColors.secondaryLabel),
                ),
              if (widget.suffix != null) ...[const SizedBox(width: 8), widget.suffix!],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(widget.errorText!, style: const TextStyle(fontSize: 12, color: AppColors.destructive)),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Android(기존 화면 외형 재현)
  // ---------------------------------------------------------------------

  Widget _buildMaterial(BuildContext context) {
    final decoration = widget.materialDecoration ??
        InputDecoration(
          labelText: widget.label,
          hintText: widget.placeholder,
          errorText: widget.errorText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          contentPadding: Responsive.responsivePadding(context, 12, 12),
          prefixIcon: widget.prefix,
          suffixIcon: widget.showObscureToggle
              ? IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : widget.suffix,
        );

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      style: widget.style ?? TextStyle(fontSize: Responsive.responsiveFontSize(context, 16)),
      decoration: decoration,
    );
  }
}
