import 'package:flutter/material.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/alarm/ui/alarm_list.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AlarmBottomNavigation extends StatelessWidget {
  final int currentIndex; // 0: alarm, 1: fam, 2: home, 3: calendar, 4: my
  const AlarmBottomNavigation({super.key, this.currentIndex = 0});

  @override
  Widget build(BuildContext context) {
    PageRouteBuilder<T> _noAnimRoute<T>(Widget page) {
      return PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    // 화면 크기에 따라 아이콘 크기와 간격을 동적으로 조정
    // 작은 화면(360px 이하): 아이콘 38px, 간격 24px
    // 중간 화면(360-400px): 아이콘 42px, 간격 32px
    // 큰 화면(400px 이상): 아이콘 45px, 간격 40px
    final iconSize = screenWidth <= 360
        ? 38.0
        : screenWidth <= 400
        ? 42.0
        : 45.0;
    final iconSpacing = screenWidth <= 360
        ? 24.0
        : screenWidth <= 400
        ? 32.0
        : 40.0;

    return Container(
      padding: EdgeInsets.only(top: 16, bottom: 16 + bottomPadding - 8),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 252, 252, 252),
        boxShadow: [
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 화면 너비가 매우 작은 경우 간격을 더 줄임
            final adjustedSpacing = constraints.maxWidth < 340
                ? iconSpacing * 0.7
                : iconSpacing;
            final adjustedIconSize = constraints.maxWidth < 340
                ? iconSize * 0.9
                : iconSize;

            return Transform.translate(
              offset: const Offset(-4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(_noAnimRoute(const AlarmPage()));
                    },
                    child: SvgPicture.asset(
                      currentIndex == 0
                          ? 'assets/images/navicon/alarm_active.svg'
                          : 'assets/images/navicon/alarm_deactive.svg',
                      width: adjustedIconSize,
                      height: adjustedIconSize,
                    ),
                  ),
                  SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFFEBF0FF),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
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
                              padding: EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                bottomSafe,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    '곧 출시될 기능입니다',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '가족과 복약을 함께 관리하는 기능이 준비 중이에요.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: SvgPicture.asset(
                      currentIndex == 1
                          ? 'assets/images/navicon/fam_active.svg'
                          : 'assets/images/navicon/fam_deactive.svg',
                      width: adjustedIconSize,
                      height: adjustedIconSize,
                    ),
                  ),
                  SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(_noAnimRoute(const HomePage()));
                    },
                    child: SvgPicture.asset(
                      currentIndex == 2
                          ? 'assets/images/navicon/home_active.svg'
                          : 'assets/images/navicon/home_deactive.svg',
                      width: adjustedIconSize,
                      height: adjustedIconSize,
                    ),
                  ),
                  SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(_noAnimRoute(const CalendarPage()));
                    },
                    child: SvgPicture.asset(
                      currentIndex == 3
                          ? 'assets/images/navicon/his_active.svg'
                          : 'assets/images/navicon/his_deactive.svg',
                      width: adjustedIconSize,
                      height: adjustedIconSize,
                    ),
                  ),
                  SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(_noAnimRoute(const MyPage()));
                    },
                    child: SvgPicture.asset(
                      currentIndex == 4
                          ? 'assets/images/navicon/my_active.svg'
                          : 'assets/images/navicon/my_deactive.svg',
                      width: adjustedIconSize,
                      height: adjustedIconSize,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
