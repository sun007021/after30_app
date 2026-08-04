import 'package:after30/features/family/ui/widgets/family_warn_icon.dart';
import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

class FamilyPhoneRegisterPopup extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onGoToMyPage;

  const FamilyPhoneRegisterPopup({
    super.key,
    required this.onCancel,
    required this.onGoToMyPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Responsive.responsivePaddingLTRB(context, 10, 20, 10, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FamilyWarnIcon(),
          SizedBox(height: Responsive.responsiveHeight(context, 20)),
          Text(
            '전화번호를 등록해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 15),
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 15)),
          Text(
            '가족 공유를 시작하려면 먼저\n전화번호를 등록해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 11),
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 15 / 11,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 116,
                height: 34,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF2F3),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 13),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 116,
                height: 34,
                child: TextButton(
                  onPressed: onGoToMyPage,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2370FF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: Text(
                    '마이페이지로 이동',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 13),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
