import 'package:after30/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FamilyEmptyState extends StatelessWidget {
  final VoidCallback onCreateGroup;

  const FamilyEmptyState({super.key, required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 42, 24, 42, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: Responsive.responsiveValue(context, 291),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              Responsive.responsiveValue(context, 24),
            ),
            border: Border.all(color: const Color(0xFFA4A4A4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: Responsive.responsiveHeight(context, 8)),
              SvgPicture.asset(
                'assets/images/fam_empty.svg',
                width: Responsive.responsiveValue(context, 150),
                height: Responsive.responsiveValue(context, 138),
                fit: BoxFit.contain,
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 12)),
              Text(
                '등록된 가족이 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 7)),
              Text(
                '등록한 가족이 약을 복용했는지 볼 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 10),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF727272),
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 16)),
              _CreateGroupButton(onPressed: onCreateGroup),
              SizedBox(height: Responsive.responsiveHeight(context, 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateGroupButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF235DFF),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: Responsive.responsiveValue(context, 28),
          padding: EdgeInsets.only(
            left: Responsive.responsiveValue(context, 15),
            right: Responsive.responsiveValue(context, 12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '새 그룹 생성하기',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.28,
                ),
              ),
              SizedBox(width: Responsive.responsiveValue(context, 6)),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: Responsive.responsiveValue(context, 14),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
