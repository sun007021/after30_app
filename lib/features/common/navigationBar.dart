import 'package:flutter/material.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/alarm/ui/alarm_list.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:after30/utils/responsive.dart';
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
    final iconSize = Responsive.responsiveIconSize(context, 45);
    final iconSpacing = screenWidth <= 360
        ? 32.0
        : screenWidth <= 400
        ? 40.0
        : screenWidth <= 430
        ? 48.0
        : 56.0;

    return Container(
      // edge-to-edge에서 하단 시스템 바(제스처 바 포함) 높이를 직접 더한다.
      // 값은 기존과 동일(8 + 인셋). 아래 SafeArea는 네 방향 모두 false라
      // 인셋을 소비하지 않으므로 이 계산이 유일한 하단 인셋 처리다.
      padding: EdgeInsets.only(top: 16, bottom: 8 + bottomPadding),
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
            // 기존 간격(32/40/48)을 유지하되, 매우 작은 화면에서만 축소
            final adjustedSpacing = constraints.maxWidth < 340
                ? iconSpacing * 0.7
                : iconSpacing;

            return Row(
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
                      width: iconSize,
                      height: iconSize,
                    ),
                  ),
                  SizedBox(width: adjustedSpacing),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(_noAnimRoute(const FamilyPage()));
                    },
                    child: SvgPicture.asset(
                      currentIndex == 1
                          ? 'assets/images/navicon/fam_active.svg'
                          : 'assets/images/navicon/fam_deactive.svg',
                      width: iconSize,
                      height: iconSize,
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
                      width: iconSize,
                      height: iconSize,
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
                      width: iconSize,
                      height: iconSize,
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
                      width: iconSize,
                      height: iconSize,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
