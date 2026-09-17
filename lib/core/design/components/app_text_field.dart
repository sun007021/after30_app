import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';
import 'package:after30/core/design/components/keyboard_done_bar.dart';

/// 플랫폼 적응형 텍스트필드.
///
/// iOS: 배경 `#F2F2F7` 계열, 곡률 sm, 포커스 시 브랜드 블루 테두리, 입력값이
/// 있을 때 clear 버튼, 숫자/전화 패드에는 [KeyboardDoneBar]를 붙인다.
/// Android: 기존 화면들이 쓰던 [TextField]/[TextFormField] 외형을 그대로
/// 재현한다(외형 변경 없음).
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
    this.readOnly = false,
    this.onSubmitted,
    this.onChanged,
    this.showKeyboardDoneBar = false,
    this.focusNode,
    this.enabled = true,
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
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// iOS 숫자/전화 패드 위에 "완료" 액세서리 바를 표시할지 여부.
  final bool showKeyboardDoneBar;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  bool _obscure = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _handleTextChange() {
    // clear 버튼 표시 여부 갱신을 위해 리빌드만 트리거한다.
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  bool get _isNumericPad =>
      widget.keyboardType == TextInputType.phone || widget.keyboardType == TextInputType.number;

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

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.borderRadius(AppRadius.sm),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 46,
          child: Row(
            children: [
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
                  readOnly: widget.readOnly,
                  enabled: widget.enabled,
                  autofillHints: widget.autofillHints,
                  onSubmitted: widget.onSubmitted,
                  onChanged: widget.onChanged,
                  padding: EdgeInsets.zero,
                  style: const TextStyle(fontSize: 17, color: AppColors.label),
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
                ),
              if (!widget.showObscureToggle && _controller.text.isNotEmpty && !widget.readOnly)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 18, color: AppColors.secondaryLabel),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(widget.errorText!, style: const TextStyle(fontSize: 12, color: AppColors.destructive)),
        ],
      ],
    );

    if (!widget.showKeyboardDoneBar || !_isNumericPad) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        KeyboardDoneBar(
          visible: _focused,
          onDone: () => _focusNode.unfocus(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Android(기존 화면 외형 재현)
  // ---------------------------------------------------------------------

  Widget _buildMaterial(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.placeholder,
        errorText: widget.errorText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        suffixIcon: widget.showObscureToggle
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
