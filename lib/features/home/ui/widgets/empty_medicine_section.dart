import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/utils/responsive.dart';

/// 약이 없을 때 표시되는 빈 상태 섹션
class EmptyMedicineSection extends StatelessWidget {
  final VoidCallback onAdd;
  final String? title;

  const EmptyMedicineSection({super.key, required this.onAdd, this.title});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    return Padding(
      padding: Responsive.responsivePadding(context, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: Responsive.responsiveHeight(context, 8)),
          SvgPicture.asset(
            'assets/images/medi_icon.svg',
            width: Responsive.responsiveValue(context, 100),
            height: Responsive.responsiveValue(context, 100),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 50)),
          Text(
            title ?? '등록된 약이 없어요',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 13),
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 14)),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.responsiveValue(context, 40),
                vertical: Responsive.responsiveValue(context, 5),
              ),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.responsiveValue(context, 4),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '약 등록하기',
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: Responsive.responsiveWidth(context, 8)),
                Icon(
                  Icons.add,
                  size: Responsive.responsiveIconSize(context, 18),
                  color: Colors.white,
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 8)),
        ],
      ),
    );
  }
}
