import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_typography.dart';

/// 적응형 내비게이션 바(§4.3).
///
/// iOS: 셰브론 뒤로 가기, 17pt semibold 중앙 제목, `largeTitle` 옵션 시
/// 컴팩트 바 아래에 34pt bold 큰 제목을 추가로 표시한다.
/// Android: 화살표 뒤로 가기, 동일한 중앙 제목 레이아웃(외형은 텍스트
/// 스타일만 다를 뿐 구조는 동일하게 유지해 회귀가 없도록 한다).
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({
    super.key,
    this.title,
    this.actions = const [],
    this.showBackButton = true,
    this.onBack,
    this.largeTitle = false,
  });

  final String? title;
  final List<Widget> actions;

  /// false면 뒤로 가기 버튼을 그리지 않는다(탭 루트 화면 등).
  final bool showBackButton;

  /// 지정하지 않으면 `Navigator.maybePop`을 호출한다.
  final VoidCallback? onBack;

  /// true면 컴팩트 바 아래에 Large Title을 추가로 표시한다.
  final bool largeTitle;

  static const double _compactHeight = 44;
  static const double _largeTitleExtra = 64;

  @override
  Size get preferredSize => Size.fromHeight(_compactHeight + (largeTitle ? _largeTitleExtra : 0));

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = showBackButton && (onBack != null || canPop);

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Column(
            children: [
              SizedBox(
                height: _compactHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!largeTitle && title != null)
                      Text(title!, style: AppTypography.title),
                    Row(
                      children: [
                        if (showBack)
                          _BackButton(cupertino: cupertino, onTap: onBack ?? () => Navigator.of(context).maybePop())
                        else
                          const SizedBox(width: 44, height: 44),
                        const Spacer(),
                        ...actions,
                        if (actions.isEmpty) const SizedBox(width: 44, height: 44),
                      ],
                    ),
                  ],
                ),
              ),
              if (largeTitle && title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title!, style: AppTypography.largeTitle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.cupertino, required this.onTap});

  final bool cupertino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(cupertino ? CupertinoIcons.chevron_back : Icons.arrow_back),
        color: AppColors.label,
      ),
    );
  }
}
