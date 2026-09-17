import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// [AppGroupedSection] 안에 들어가는 한 행.
///
/// iOS: inset grouped 목록 행(흰 배경, inset 구분선, 셰브론, destructive
/// 빨간 텍스트). Android: `card_container.dart`/`link_list.dart`가 쓰던
/// 흰 카드 + InkWell 행 스타일을 재현한다.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// true면 우측에 셰브론을 표시한다(trailing이 없을 때만).
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final titleColor = destructive ? AppColors.destructive : AppColors.label;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: cupertino ? 17 : 14, color: titleColor),
                  ),
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
    );
  }
}

/// 여러 [AppListTile]을 하나의 그룹으로 묶는 컨테이너(§4.3).
///
/// iOS: 배경 `#F2F2F7`(inset grouped) 위에 흰 카드, inset 구분선.
/// Android: 흰 카드(기존 `CardContainer` 외형과 동일한 곡률/배경).
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({super.key, this.header, required this.children});

  /// 그룹 상단에 표시할 소제목(선택).
  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final radius = cupertino ? AppRadius.md : AppRadius.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              header!,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
            ),
          ),
        ClipRRect(
          borderRadius: AppRadius.borderRadius(radius),
          child: Container(
            color: AppColors.surface,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Divider(height: 1, thickness: 1, color: AppColors.divider),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
