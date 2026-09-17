import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';

/// [AppSegmentedControl]의 개별 옵션.
class AppSegmentedOption<T> {
  const AppSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 선택지 2~4개짜리 적응형 세그먼트 컨트롤(§4.3).
///
/// iOS: [CupertinoSlidingSegmentedControl]. Android: `my_info_widgets.dart`의
/// 기존 성별 선택 라디오 스타일(원형 테두리 + 라벨)을 그대로 재현한다.
class AppSegmentedControl<T extends Object> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegmentedOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        thumbColor: AppColors.primary,
        children: {
          for (final option in options)
            option.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                option.label,
                style: TextStyle(
                  color: value == option.value ? Colors.white : AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        },
        onValueChanged: (v) {
          if (v == null) return;
          AppHaptics.selection(context);
          onChanged(v);
        },
      );
    }

    // Android: 기존 성별 선택 라디오 스타일을 재현한다.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 50),
          _AndroidRadioOption<T>(
            option: options[i],
            selected: value == options[i].value,
            onTap: () => onChanged(options[i].value),
          ),
        ],
      ],
    );
  }
}

class _AndroidRadioOption<T> extends StatelessWidget {
  const _AndroidRadioOption({required this.option, required this.selected, required this.onTap});

  final AppSegmentedOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primaryAlt : const Color(0xFFD8D8D8),
                width: selected ? 5 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            option.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
