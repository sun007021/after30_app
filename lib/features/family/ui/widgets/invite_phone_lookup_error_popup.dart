import 'package:after30/features/family/ui/widgets/family_warn_icon.dart';
import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

class InvitePhoneLookupErrorPopup extends StatelessWidget {
  final VoidCallback onConfirm;

  const InvitePhoneLookupErrorPopup({super.key, required this.onConfirm});

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
            '조회할 수 없습니다',
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
            '초대할 사용자가 전화번호를 등록해야\n초대가 가능합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 11),
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 15 / 11,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 20)),
          SizedBox(
            width: 116,
            height: 34,
            child: TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEFF2F3),
                foregroundColor: Colors.black,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
