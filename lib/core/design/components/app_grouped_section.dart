import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';
import 'package:after30/utils/responsive.dart';

/// [AppGroupedSection] 안에 들어가는 한 행.
///
/// iOS: inset grouped 목록 행(흰 배경, inset 구분선, 셰브론, destructive
/// 빨간 텍스트, 17pt). Android: 기존 `card_container.dart` +
/// `link_list.dart` 조합이 쓰던 값(12pt, 세로 패딩 8, 구분선 없음)을
/// 그대로 맞춘다.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingWidth,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// [leading]의 대략적인 폭(pt). 지정하면 [AppGroupedSection]이 구분선의
  /// 들여쓰기를 이 행의 본문 시작 위치에 맞춰 계산한다(기본값 24).
  final double? leadingWidth;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// true면 우측에 셰브론을 표시한다(trailing이 없을 때만).
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final titleColor = destructive ? AppColors.destructive : AppColors.label;
    final fontSize = cupertino ? 17.0 : Responsive.responsiveFontSize(context, 12);
    final verticalPadding = cupertino ? 10.0 : Responsive.responsiveValue(context, 8);

    // InkWell의 물결 효과는 가장 가까운 조상 Material의 페인트 레이어에
    // 그려진다. 이 행을 감싸는 별도의 투명 Material이 없으면 위쪽 화면의
    // Material(예: Scaffold)까지 올라가 다른 형제 위젯 밑에 가려 보이지
    // 않을 수 있으므로, 행마다 로컬 Material로 감싼다.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontSize: fontSize, color: titleColor)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && showChevron)
                Icon(
                  cupertino ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                  size: 18,
                  color: AppColors.secondaryLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 여러 [AppListTile]을 하나의 그룹으로 묶는 컨테이너(§4.3).
///
/// iOS: 흰 카드(연속 곡률, `ClipRSuperellipse`) + inset 구분선. 바깥의
/// `#F2F2F7`(inset grouped) 배경은 이 컴포넌트가 직접 그리지 않는다 —
/// 여러 섹션 사이 간격까지 화면 전체에 이어지는 배경이라 섹션 단위가
/// 아니라 화면(Scaffold)이 제공해야 한다. 이 컴포넌트를 쓰는 화면은
/// `Scaffold(backgroundColor: AppColors.groupedBackground)`를 지정한다.
/// Android: 기존 `card_container.dart`가 쓰던 값(반응형 반지름 5)을 그대로
/// 맞추고 구분선은 넣지 않는다(`link_list.dart`와 동일).
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({super.key, this.header, required this.children});

  /// 그룹 상단에 표시할 소제목(선택).
  final String? header;
  final List<Widget> children;

  double _dividerInsetFor(Widget tile) {
    if (tile is AppListTile && tile.leading != null) {
      return 16 + (tile.leadingWidth ?? 24) + 12;
    }
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final radius = cupertino ? AppRadius.md : Responsive.responsiveValue(context, 5);
    final borderRadius = BorderRadius.circular(radius);

    final body = Container(
      color: AppColors.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            // Android(card_container/link_list)는 행 사이에 구분선을 쓰지
            // 않는다. iOS만 inset 구분선을 그린다.
            if (cupertino && i != children.length - 1)
              Padding(
                padding: EdgeInsets.only(left: _dividerInsetFor(children[i])),
                child: const Divider(height: 1, thickness: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(header!, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
          ),
        cupertino
            ? ClipRSuperellipse(borderRadius: borderRadius, child: body)
            : ClipRRect(borderRadius: borderRadius, child: body),
      ],
    );
  }
}
