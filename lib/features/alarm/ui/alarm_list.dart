import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:after30/utils/responsive.dart';

class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: Responsive.responsiveHeight(context, 32)),
            Padding(
              padding: Responsive.responsivePadding(context, 24, 0),
              child: Row(
                children: [
                  Text(
                    '등록된 약',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 20),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
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
                          final bottomSafe = MediaQuery.of(
                            ctx,
                          ).viewPadding.bottom;
                          return SafeArea(
                            top: false,
                            left: false,
                            right: false,
                            bottom: true,
                            child: Padding(
                              padding: Responsive.responsivePaddingLTRB(
                                ctx,
                                20,
                                20,
                                20,
                                0,
                              ).copyWith(bottom: bottomSafe),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '곧 출시될 기능입니다',
                                    style: TextStyle(
                                      fontSize: Responsive.responsiveFontSize(
                                        ctx,
                                        18,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.responsiveHeight(ctx, 8),
                                  ),
                                  Text(
                                    '더 빠른 약 등록을 위한 NFC 관리 기능을 만들고 있어요.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: Responsive.responsiveFontSize(
                                        ctx,
                                        14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 0,
                        top: Responsive.responsiveValue(context, 52),
                        bottom: Responsive.responsiveValue(context, 8),
                      ),
                      child: Text(
                        'NFC 관리하기',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: Responsive.responsiveFontSize(context, 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 본문 리스트는 스크롤되지만, 위의 헤더 Row는 고정
            const AlarmContent(),
          ],
        ),
      ),
    );
  }
}
