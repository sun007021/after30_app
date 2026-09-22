import 'package:flutter/cupertino.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 숫자/전화 패드에는 Return 키가 없으므로, 키보드 위에 "완료" 액세서리
/// 바를 붙여 포커스를 내릴 수 있게 한다(iOS 전용, §4.3).
///
/// `AppTextField`는 이 위젯을 본문 레이아웃에 인라인으로 넣지 않고, 포커스가
/// 있는 동안 루트 [Overlay] 위에 `bottom: MediaQuery.viewInsetsOf(...).bottom`
/// 위치로 직접 띄운다(키보드 바로 위에 붙어 있어야 하므로). 그 밖의 자리에서
/// 직접 쓸 때는 [visible]로 노출 여부를 제어하면 된다.
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
