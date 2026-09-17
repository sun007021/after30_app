import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// 그래버 + 상단 곡률 xl을 갖는 적응형 바텀 시트(§4.3).
///
/// iOS/Android 모두 [showModalBottomSheet]를 기반으로 하되, iOS에서는
/// Cupertino 시트 느낌(그래버, 큰 상단 곡률)을 강조한다.
///
/// `isScrollControlled: true`는 시트가 화면 높이에 맞춰 커질 수 있게 할
/// 뿐, 키보드를 자동으로 피해주지는 않는다(오해하기 쉬운 부분). 그래서
/// 내부에서 [MediaQuery.viewInsetsOf]만큼 아래쪽 패딩을 직접 더해, 시트
/// 안에 텍스트필드가 있어도 키보드가 필드를 가리지 않게 한다.
///
/// 디텐트(medium/large 등 여러 높이 단계)는 아직 지원하지 않는다. 필요해
/// 지면 `DraggableScrollableSheet` 기반의 `initialChildSize`/`expandable`
/// 옵션을 추가하는 후속 작업으로 진행한다(현재는 실제 화면에서 쓰이지
/// 않아 범위를 최소로 유지했다).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final cupertino = isCupertino(context);
  return showModalBottomSheet<T>(
    context: context,
    // W10에서 탭별 Navigator + 플로팅 탭바를 도입할 예정이므로, 시트가
    // 항상 루트 Navigator 위(탭 셸보다 위)에 표시되도록 고정한다.
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      final topRadius = Radius.circular(cupertino ? AppRadius.xl : AppRadius.md);
      final shape = cupertino
          ? RoundedSuperellipseBorder(borderRadius: BorderRadius.vertical(top: topRadius))
          : RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: topRadius));

      return AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: AppColors.surface, shape: shape),
          // 배경(흰색)은 홈 인디케이터 영역까지 그대로 채우고, 내용만
          // SafeArea로 안쪽에 여백을 준다(그래야 실제 iOS 시트처럼 흰
          // 배경이 화면 맨 아래까지 이어진다).
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLabel.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
