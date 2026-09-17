import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_typography.dart';
import 'package:after30/utils/responsive.dart';

/// 적응형 내비게이션 바(§4.3).
///
/// iOS: 셰브론 뒤로 가기, 17pt semibold 중앙 제목, `largeTitle` 옵션 시
/// 컴팩트 바 아래에 34pt bold 큰 제목을 추가로 표시한다.
/// Android: `my_info_widgets.dart`의 `MyInfoHeader`가 쓰던
/// `Icons.arrow_back_ios_new` 뒤로 가기, 동일한 중앙 제목 레이아웃(외형은
/// 텍스트 스타일만 다를 뿐 구조는 동일하게 유지해 회귀가 없도록 한다).
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

  /// 제목 영역 양옆에 확보하는 여백. 뒤로가기 버튼/트레일링 액션이 보통
  /// 이 범위 안에 들어오므로 제목이 그것들과 겹치지 않는다(정확한 폭
  /// 측정 대신 실용적인 고정값을 사용한다).
  static const double _titleHorizontalReserve = 56;

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
                      Positioned.fill(
                        left: _titleHorizontalReserve,
                        right: _titleHorizontalReserve,
                        child: Center(
                          child: Text(
                            title!,
                            style: _titleStyle(context, cupertino),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
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

  TextStyle _titleStyle(BuildContext context, bool cupertino) {
    if (cupertino) return AppTypography.title;
    return AppTypography.title.copyWith(fontSize: Responsive.responsiveFontSize(context, 17));
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
        icon: Icon(
          cupertino ? CupertinoIcons.chevron_back : Icons.arrow_back_ios_new,
          size: cupertino ? 24 : Responsive.responsiveIconSize(context, 22),
        ),
        color: AppColors.label,
      ),
    );
  }
}

/// [CustomScrollView]의 sliver 자리에 넣는, 스크롤에 따라 접히는 큰 제목
/// 내비게이션 바(§4.3, W10의 홈/알람 목록 등 최상위 탭 화면용).
///
/// iOS: 실제 [CupertinoSliverNavigationBar]를 그대로 사용해 네이티브와
/// 동일한 접힘 애니메이션을 낸다. Android: 기존 상단 바 스타일을 유지하는
/// [SliverAppBar](고정, 확장/축소 없음)를 사용한다.
class AppSliverNavBar extends StatelessWidget {
  const AppSliverNavBar({
    super.key,
    this.title,
    this.actions = const [],
    this.showBackButton = true,
    this.onBack,
  });

  final String? title;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: title != null ? Text(title!) : null,
        backgroundColor: AppColors.surface,
        leading: showBackButton
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                child: const Icon(CupertinoIcons.chevron_back),
              )
            : null,
        automaticallyImplyLeading: showBackButton,
        trailing: actions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
    }

    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.label,
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: Responsive.responsiveIconSize(context, 22)),
              color: AppColors.label,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      title: title != null
          ? Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(fontSize: Responsive.responsiveFontSize(context, 17)),
            )
          : null,
      actions: actions,
    );
  }
}
