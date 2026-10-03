import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

/// 링크 리스트 위젯
///
/// iOS: inset grouped 목록([AppGroupedSection]). [destructiveIndexes]의 행은
/// 빨간 텍스트로 표시하고, [showChevron]이 true면 셰브론을 붙인다.
/// Android: 기존 텍스트 목록 그대로.
class LinkList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onTapIndex;

  /// iOS 전용 옵션들.
  final String? header;
  final Set<int> destructiveIndexes;
  final bool showChevron;

  const LinkList({
    super.key,
    required this.items,
    required this.onTapIndex,
    this.header,
    this.destructiveIndexes = const {},
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return AppGroupedSection(
        header: header,
        children: [
          for (int i = 0; i < items.length; i++)
            AppListTile(
              title: items[i],
              destructive: destructiveIndexes.contains(i),
              showChevron: showChevron && !destructiveIndexes.contains(i),
              onTap: () => onTapIndex(i),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          InkWell(
            onTap: () => onTapIndex(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                items[i],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
