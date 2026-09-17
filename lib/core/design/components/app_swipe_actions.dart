import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';

/// 목록 행을 좌측으로 스와이프해 삭제하는 적응형 위젯(§4.3).
///
/// iOS: 별도 패키지 없이 드래그 제스처로 빨간 삭제 버튼을 노출한다(트레일링
/// 스와이프 액션 근사). Android: 기존 [Dismissible] 동작을 그대로 사용한다.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDelete,
    this.deleteLabel = '삭제',
    this.confirmDismiss,
  });

  /// [Dismissible]에 필요한 고유 키(Android 경로에서 사용).
  final Key itemKey;
  final Widget child;

  /// 삭제가 확정되었을 때 호출된다.
  final VoidCallback onDelete;
  final String deleteLabel;

  /// Android [Dismissible.confirmDismiss]와 동일. iOS 경로에서는 삭제 버튼
  /// 탭 시 호출해 확인을 받는다.
  final Future<bool> Function()? confirmDismiss;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

class _AppSwipeActionsState extends State<AppSwipeActions> {
  static const double _actionWidth = 72;
  double _dragExtent = 0;

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = widget.confirmDismiss == null ? true : await widget.confirmDismiss!();
    if (!confirmed || !context.mounted) return;
    AppHaptics.warning(context);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCupertino(context)) {
      return Dismissible(
        key: widget.itemKey,
        direction: DismissDirection.endToStart,
        confirmDismiss: widget.confirmDismiss == null ? null : (_) => widget.confirmDismiss!(),
        onDismissed: (_) => widget.onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          color: AppColors.destructive,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(widget.deleteLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        child: widget.child,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent = (_dragExtent + details.delta.dx).clamp(-_actionWidth, 0.0);
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _dragExtent = _dragExtent < -_actionWidth / 2 ? -_actionWidth : 0;
        });
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () async {
                await _handleDelete(context);
                if (mounted) setState(() => _dragExtent = 0);
              },
              child: Container(
                color: AppColors.destructive,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.deleteLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            color: AppColors.surface,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
