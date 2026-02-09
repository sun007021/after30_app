import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/utils/responsive.dart';

/// 알람이 없을 때 표시되는 빈 상태 섹션
class EmptyAlarmSection extends StatelessWidget {
  final VoidCallback onAdd;

  const EmptyAlarmSection({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: Responsive.responsivePaddingLTRB(context, 24, 80, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(height: Responsive.responsiveHeight(context, 70)),
              SvgPicture.asset(
                'assets/images/medimain.svg',
                width: Responsive.responsiveValue(context, 100),
                height: Responsive.responsiveValue(context, 100),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 32)),
              Text(
                '등록된 약이 없어요!',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 18),
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 12)),
              const Spacer(),
              FractionallySizedBox(
                widthFactor: 0.9,
                child: SizedBox(
                  height: Responsive.responsiveValue(context, 45),
                  child: ElevatedButton(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF235DFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.responsiveValue(context, 6),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: Responsive.responsiveValue(context, 16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '약 등록하기',
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                17,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(
                            width: Responsive.responsiveWidth(context, 8),
                          ),
                          Icon(
                            Icons.add,
                            size: Responsive.responsiveIconSize(context, 25),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 12)),
            ],
          ),
        ),
      ),
    );
  }
}
