import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';

/// 목록 행을 좌측으로 스와이프해 삭제하는 적응형 위젯(§4.3).
///
/// iOS: 별도 패키지 없이 드래그 제스처로 빨간 삭제 버튼을 노출한다(트레일링
/// 스와이프 액션 근사). 드래그 중에는 즉시(애니메이션 없이) 손가락을
/// 따라가고, 손을 뗐을 때만(fling 속도 또는 절반 이상 열림 기준으로 열지
/// 닫을지 판단) 애니메이션으로 스냅한다. 한 번에 하나의 행만 열려 있도록
/// 정적 알림자([_openItem])로 관리하며, 다른 행이 열리거나 열려 있는 행의
/// 본문을 탭하면 닫힌다.
///
/// Android: 기존 [Dismissible] 동작을 그대로 사용한다. **주의**:
/// [Dismissible]은 `onDismissed` 콜백이 끝나기 전에 위젯 트리에서 해당
/// 항목이 동기적으로 제거되어야 한다(그렇지 않으면 "A dismissed Dismissible
/// widget is still part of the tree" 오류가 발생한다). 즉 [onDelete] 호출자는
/// 리스트에서 항목을 제거하는 `setState`(또는 동등한 상태 갱신)를 콜백 안에서
/// 동기적으로 수행해야 한다.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    super.key,
    required this.itemKey,
    required this.child,
    required this.onDelete,
    this.deleteLabel = '삭제',
    this.confirmDismiss,
  });

  /// [Dismissible]에 필요한 고유 키(Android 경로에서 사용)이자, iOS 경로에서
  /// "지금 열려 있는 행"을 구분하는 식별자로도 쓰인다.
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

class _AppSwipeActionsState extends State<AppSwipeActions> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 72;
  static const double _flingVelocityThreshold = 500; // px/s

  /// 현재 열려 있는 행의 [itemKey]. 한 시점에 하나만 열려 있게 한다.
  static final ValueNotifier<Key?> _openItem = ValueNotifier<Key?>(null);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _openItem.addListener(_handleOpenItemChanged);
  }

  void _handleOpenItemChanged() {
    if (_openItem.value != widget.itemKey && _controller.value != 0) {
      _controller.animateTo(0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _openItem.removeListener(_handleOpenItemChanged);
    _controller.dispose();
    super.dispose();
  }

  void _closeSelf() {
    _controller.animateTo(0, curve: Curves.easeOut);
    if (_openItem.value == widget.itemKey) _openItem.value = null;
  }

  void _openSelf() {
    _controller.animateTo(1, curve: Curves.easeOut);
    _openItem.value = widget.itemKey;
  }

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

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.deleteLabel): () => _handleDelete(context),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          // 드래그 중에는 애니메이션 없이 즉시 손가락을 따라간다.
          final next = (_controller.value - details.delta.dx / _actionWidth).clamp(0.0, 1.0);
          _controller.value = next;
        },
        onHorizontalDragEnd: (details) {
          final velocity = -details.velocity.pixelsPerSecond.dx; // 양수: 왼쪽(열림) 방향
          final shouldOpen = velocity > _flingVelocityThreshold
              ? true
              : velocity < -_flingVelocityThreshold
                  ? false
                  : _controller.value > 0.5;
          if (shouldOpen) {
            _openSelf();
          } else {
            _closeSelf();
          }
        },
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  await _handleDelete(context);
                  if (mounted) _closeSelf();
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
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-_controller.value * _actionWidth, 0),
                  child: child,
                );
              },
              child: GestureDetector(
                // 열려 있는 상태에서 본문(삭제 버튼이 아닌 영역)을 탭하면
                // 닫는다("열린 행 바깥을 탭하면 닫힌다"의 자기 자신 케이스).
                // AnimatedBuilder의 child는 매 프레임 재생성되지 않으므로,
                // onTap 콜백 내부에서 _controller.value를 탭 시점에 읽는다.
                onTap: () {
                  if (_controller.value > 0) _closeSelf();
                },
                child: ColoredBox(color: AppColors.surface, child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
