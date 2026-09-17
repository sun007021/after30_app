import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// 그래버 + 상단 곡률 xl을 갖는 적응형 바텀 시트(§4.3).
///
/// iOS/Android 모두 [showModalBottomSheet]를 기반으로 하되, iOS에서는
/// Cupertino 시트 느낌(그래버, 큰 상단 곡률)을 강조한다. `isScrollControlled`는
/// 항상 true로 두어 키보드가 올라와도 시트가 밀리지 않게 한다.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final cupertino = isCupertino(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(cupertino ? AppRadius.xl : AppRadius.md),
            ),
          ),
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
      );
    },
  );
}
