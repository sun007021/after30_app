import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:after30/utils/responsive.dart';

/// 약 추가 타일 위젯
class AddMedicineTile extends StatelessWidget {
  final VoidCallback onAdd;

  const AddMedicineTile({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Responsive.responsiveValue(context, 12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 12),
        ),
        onTap: onAdd,
        child: DottedBorder(
          color: const Color(0xFFBDBDBD),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          borderType: BorderType.RRect,
          radius: Radius.circular(Responsive.responsiveValue(context, 12)),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: EdgeInsets.symmetric(
              vertical: Responsive.responsiveValue(context, 20),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.add,
                  color: Colors.black54,
                  size: Responsive.responsiveIconSize(context, 24),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 4)),
                Text(
                  '추가하기',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: Responsive.responsiveFontSize(context, 14),
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
