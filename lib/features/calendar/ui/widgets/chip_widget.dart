import 'package:flutter/material.dart';

/// 재사용 가능한 칩 위젯
class CustomChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;
  final Widget? leading;

  const CustomChip({
    super.key,
    required this.text,
    this.bg = const Color(0xFFFCFCFC),
    this.fg = Colors.black87,
    this.border,
    this.icon,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
