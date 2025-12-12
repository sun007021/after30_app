import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 약이 없을 때 표시되는 빈 상태 섹션
class EmptyMedicineSection extends StatelessWidget {
  final VoidCallback onAdd;
  final String? title;

  const EmptyMedicineSection({super.key, required this.onAdd, this.title});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SvgPicture.asset(
            'assets/images/medi_icon.svg',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 50),
          Text(
            title ?? '등록된 약이 없어요',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '약 등록하기',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                Icon(Icons.add, size: 18, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
