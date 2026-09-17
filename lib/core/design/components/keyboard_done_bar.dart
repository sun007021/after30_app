import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 숫자/전화 패드에는 Return 키가 없으므로, 키보드 위에 "완료" 액세서리
/// 바를 붙여 포커스를 내릴 수 있게 한다(iOS 전용, §4.3).
///
/// [FocusNode]에 포커스가 있을 때만 [InputDecoration.suffixIcon] 대신
/// 화면 하단에 떠 있는 형태로 쓰기보다는, 각 필드가 `Column`으로
/// [KeyboardDoneBar]를 감싸고 [visible]로 노출 여부를 제어하는 방식을
/// 권장한다(`AppTextField`가 내부적으로 이렇게 사용한다).
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key, required this.visible, required this.onDone, this.label = '완료'});

  final bool visible;
  final VoidCallback onDone;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: 44,
      color: CupertinoColors.systemGrey6,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onDone,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ),
    );
  }
}
