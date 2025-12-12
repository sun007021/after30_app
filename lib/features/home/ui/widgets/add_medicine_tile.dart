import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

/// 약 추가 타일 위젯
class AddMedicineTile extends StatelessWidget {
  final VoidCallback onAdd;

  const AddMedicineTile({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAdd,
        child: DottedBorder(
          color: const Color(0xFFBDBDBD),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Column(
              children: const [
                Icon(Icons.add, color: Colors.black54),
                SizedBox(height: 4),
                Text('추가하기', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
