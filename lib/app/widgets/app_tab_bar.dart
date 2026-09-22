import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/utils/responsive.dart';

/// 탭 메타데이터(라벨, 아이콘 파일명 접두사). 순서는 `AppShellTab`과 같다.
class _TabMeta {
  const _TabMeta(this.label, this.assetPrefix);

  final String label;
  final String assetPrefix;
}

const List<_TabMeta> _tabMetas = [
  _TabMeta('알람', 'alarm'),
  _TabMeta('가족', 'fam'),
  _TabMeta('홈', 'home'),
  _TabMeta('기록', 'his'),
  _TabMeta('마이', 'my'),
];

/// 앱 셸 하단 탭바(plan §6 W10 2/9항). iOS/Android를 분기한다.
///
/// iOS: `GlassSurface` 기반 플로팅 캡슐, 아이콘 + 텍스트 라벨(D13).
/// Android: 기존 `AlarmBottomNavigation`과 시각적으로 동일한 탭바.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// iOS 플로팅 탭바가 화면 하단에서 차지하는 총 높이(콘텐츠가 가리지
  /// 않도록 탭 콘텐츠의 하단 패딩 계산에 쓰인다). Android는 0을 반환한다
  /// (Android는 `Scaffold.bottomNavigationBar`처럼 항상 차지하는 자리가
  /// 아니라 콘텐츠 위에 그려지므로, 기존 Android 화면들이 직접 계산하던
  /// 여백을 그대로 유지한다).
  static double reservedBottomHeight(BuildContext context) {
    if (!isCupertino(context)) return 0;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return _IosTabBar.barHeight + _IosTabBar.bottomMargin + bottomSafe;
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return _IosTabBar(currentIndex: currentIndex, onTap: onTap);
    }
    return _AndroidTabBar(currentIndex: currentIndex, onTap: onTap);
  }
}

/// Android 탭바. `navigationBar.dart`의 기존 `AlarmBottomNavigation`과
/// 동일한 에셋/크기/간격/그림자/배경을 그대로 재현하되, 화면을 직접
/// push하는 대신 [onTap]으로 셸의 탭 전환을 호출한다.
class _AndroidTabBar extends StatelessWidget {
  const _AndroidTabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = Responsive.responsiveIconSize(context, 45);
    final iconSpacing = screenWidth <= 360
        ? 32.0
        : screenWidth <= 400
        ? 40.0
        : screenWidth <= 430
        ? 48.0
        : 56.0;

    return Container(
      padding: EdgeInsets.only(top: 16, bottom: 16 + bottomPadding - 8),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 252, 252, 252),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 16, spreadRadius: 0, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final adjustedSpacing = constraints.maxWidth < 340 ? iconSpacing * 0.7 : iconSpacing;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _tabMetas.length; i++) ...[
                  if (i != 0) SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SvgPicture.asset(
                      'assets/images/navicon/${_tabMetas[i].assetPrefix}_'
                      '${currentIndex == i ? 'active' : 'deactive'}.svg',
                      width: iconSize,
                      height: iconSize,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// iOS 플로팅 캡슐 글래스 탭바(plan §4.3, §6 W10 2/9항).
class _IosTabBar extends StatelessWidget {
  const _IosTabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double barHeight = 64;
  static const double bottomMargin = 8;
  static const double sideMargin = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(sideMargin, 0, sideMargin, bottomMargin),
      child: SizedBox(
        height: barHeight,
        child: GlassSurface(
          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(barHeight / 2)),
          child: AppTypography.clampTextScale(
            child: Row(
              children: [
                for (var i = 0; i < _tabMetas.length; i++)
                  Expanded(
                    child: _IosTabItem(
                      meta: _tabMetas[i],
                      selected: currentIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IosTabItem extends StatelessWidget {
  const _IosTabItem({required this.meta, required this.selected, required this.onTap});

  final _TabMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assetPath =
        'assets/images/navicon/ios/${meta.assetPrefix}_${selected ? 'active' : 'deactive'}.svg';
    final labelColor = selected ? AppColors.label : AppColors.secondaryLabel;

    return Semantics(
      button: true,
      selected: selected,
      label: meta.label,
      // 안의 Text가 같은 라벨을 또 한 번 읽어서 "알람 알람"처럼 두 번
      // 읽히는 것을 막는다(m8) — 이 Semantics 노드가 자식들의 시맨틱스를
      // 대신하고, 자식(Text/SvgPicture)의 시맨틱스는 트리에서 제외한다.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: SvgPicture.asset(assetPath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 2),
            Text(
              meta.label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: labelColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
