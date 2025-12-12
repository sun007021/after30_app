import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/utils/responsive.dart';

class AlarmTopBar extends StatelessWidget {
  const AlarmTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: Responsive.responsiveValue(context, 8),
        bottom: Responsive.responsiveValue(context, 2),
      ),
      padding: Responsive.responsivePadding(context, 16, 0),
      child: Row(
        children: [
          const Expanded(child: Text('')),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: const Color(0xFFEBF0FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      Responsive.responsiveValue(context, 16),
                    ),
                  ),
                ),
                builder: (ctx) {
                  final bottomSafe = MediaQuery.of(ctx).viewPadding.bottom;
                  return SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: true,
                    child: Padding(
                      padding:
                          Responsive.responsivePaddingLTRB(
                            ctx,
                            20,
                            20,
                            20,
                            0,
                          ).copyWith(
                            bottom:
                                Responsive.responsiveValue(ctx, 32) +
                                bottomSafe,
                          ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '곧 출시될 기능입니다',
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(ctx, 18),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: Responsive.responsiveHeight(ctx, 8)),
                          Text(
                            '알림을 더 편하게 모아볼 수 있도록 준비하고 있어요.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: Responsive.responsiveFontSize(ctx, 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.responsiveValue(context, 10),
                vertical: Responsive.responsiveValue(context, 6),
              ),
              child: SvgPicture.asset(
                'assets/images/alarmIcon.svg',
                width: Responsive.responsiveIconSize(context, 18),
                height: Responsive.responsiveIconSize(context, 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
