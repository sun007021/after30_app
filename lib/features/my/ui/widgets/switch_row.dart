import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

/// 스위치가 있는 행 위젯
///
/// iOS: inset grouped 목록 행([AppListTile] + [AppSwitch]). 이 행들은
/// [AppGroupedSection] 안에 넣어야 한다. Android: 기존 외형 그대로.
class SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// iOS 보조 문구(Android에서는 쓰지 않는다).
  final String? subtitle;

  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return AppListTile(
        title: title,
        subtitle: subtitle,
        trailing: AppSwitch(value: value, onChanged: onChanged),
      );
    }
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF235DFF),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}
