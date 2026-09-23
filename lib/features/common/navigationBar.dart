import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_platform.dart';
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
    // 앱 셸(AppShell) 안에서는 셸 자체의 탭바가 대신 그려지므로 이 위젯은
    // 실제 탭바를 그리지 않는다(plan §6 W10 3항). 각 화면이 여전히
    // `bottomNavigationBar: AlarmBottomNavigation(...)`을 그대로 쓴다는
    // 점을 이용해, Scaffold가 알아서 자리를 예약하게 만든다(B3):
    // - Android: 셸이 진짜 탭바를 자신의 Scaffold.bottomNavigationBar
    //   슬롯에 꽂으므로, 화면별로는 자리를 또 예약할 필요가 없다(중복
    //   방지) — 높이 0.
    // - iOS: 플로팅 글래스 캡슐이 콘텐츠 위로 떠 있어야 하므로, 화면은
    //   그 높이만큼 "빈 자리"만 예약해 body/스크롤 뷰포트가 그 위에서
    //   끝나게 한다. 실제로 보이는 캡슐은 셸이 Stack으로 그 위에 그린다.
    //   이렇게 하면 Scaffold의 기본 동작(SnackBar를 bottomNavigationBar
    //   위에 띄우는 것 포함, M1)을 그대로 재사용할 수 있다.
    if (AppShell.isInside(context)) {
      if (isCupertino(context)) {
        // 셸이 예약해 둔 높이를 그대로 읽는다. 이 context는 셸 body 안이고,
        // 셸 Scaffold는 `extendBody: true` + 같은 높이의 자리표시자를
        // bottomNavigationBar에 꽂아 두므로, 여기서 보이는
        // `padding.bottom`이 곧 셸의 예약 높이다(키보드가 올라와 탭바가
        // 숨는 동안은 0).
        //
        // AppTabBar.reservedBottomHeight(context)로 다시 계산하면 안 된다
        // (N1) — 이미 부풀려진 값을 "원본 세이프 에어리어"로 착각해 실제보다
        // 훨씬 큰 값이 나온다. 셸 State의 `reservedBottom`을 읽는 것도 안
        // 된다(N8) — findAncestorStateOfType은 의존 관계를 만들지 않아서,
        // 키보드가 올라온 프레임에 push된 화면이 0을 읽고 나면 키보드가
        // 내려가도 다시 빌드되지 않아 하단이 캡슐에 영구히 가린다.
        // MediaQuery는 의존 관계가 생기므로 값이 바뀌면 자동으로 다시
        // 빌드된다.
        return SizedBox(height: MediaQuery.paddingOf(context).bottom);
      }
      return const SizedBox.shrink();
    }

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
