import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';
import 'package:after30/utils/responsive.dart';

/// [AppSegmentedControl]의 개별 옵션.
class AppSegmentedOption<T> {
  const AppSegmentedOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 선택지 2~4개짜리 적응형 세그먼트 컨트롤(§4.3).
///
/// iOS: [CupertinoSlidingSegmentedControl]. 기본값은 iOS 플랫폼 기본
/// 스타일(흰 썸, 라벨 색은 선택 여부와 무관하게 유지)이고, [tinted]를
/// true로 주면 브랜드 컬러 썸 + 선택 시 흰 텍스트로 강조할 수 있다.
/// Android: 옵션 개수에 관계없이 쓸 수 있는 일반 라디오 스타일 목록이며,
/// 기본 간격은 `my_info_widgets.dart`의 성별 선택(`MyInfoGenderSelector`)과
/// 동일하다(옵션이 2개보다 많으면 [androidSpacing]으로 간격을 조정한다).
class AppSegmentedControl<T extends Object> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.tinted = false,
    this.androidSpacing,
  });

  final List<AppSegmentedOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  /// true면 iOS에서 브랜드 컬러 썸 + 선택된 라벨을 흰색으로 강조한다.
  /// 기본값(false)은 iOS 플랫폼 기본 스타일(흰 썸, 라벨 색 고정)이다.
  final bool tinted;

  /// Android 라디오 옵션 사이의 간격. 지정하지 않으면
  /// `Responsive.responsiveWidth(context, 50)`(기존 성별 선택과 동일)을
  /// 쓴다.
  final double? androidSpacing;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        thumbColor: tinted ? AppColors.primary : CupertinoColors.white,
        children: {
          for (final option in options)
            option.value: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                option.label,
                style: TextStyle(
                  color: tinted && value == option.value ? Colors.white : AppColors.label,
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

    // Android: my_info_widgets.dart의 성별 선택과 동일한 라디오 스타일을
    // 기본값으로 쓰되, 옵션 개수와 무관하게 동작하는 일반 목록이다.
    final spacing = androidSpacing ?? Responsive.responsiveWidth(context, 50);
    return Wrap(
      spacing: spacing,
      runSpacing: 12,
      children: [
        for (final option in options)
          _AndroidRadioOption<T>(
            option: option,
            selected: value == option.value,
            onTap: () => onChanged(option.value),
          ),
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
            style: TextStyle(fontSize: Responsive.responsiveFontSize(context, 12), fontWeight: FontWeight.w400, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
