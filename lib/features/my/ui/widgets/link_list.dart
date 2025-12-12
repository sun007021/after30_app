import 'package:flutter/material.dart';

/// 링크 리스트 위젯
class LinkList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onTapIndex;

  const LinkList({super.key, required this.items, required this.onTapIndex});

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
