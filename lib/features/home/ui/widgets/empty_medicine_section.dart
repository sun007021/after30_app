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
          SizedBox(height: Responsive.responsiveHeight(context, 70)),
          SvgPicture.asset(
            'assets/images/medimain.svg',
            width: Responsive.responsiveValue(context, 100),
            height: Responsive.responsiveValue(context, 100),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 32)),
          Text(
            title ?? '등록된 약이 없어요!',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 18),
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 200)),
          FractionallySizedBox(
            child: SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        '약 등록하기',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.add, size: 25, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
