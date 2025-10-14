import 'package:flutter/material.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/alarm/ui/alarm_list.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AlarmBottomNavigation extends StatelessWidget {
  final int currentIndex; // 0: alarm, 1: fam, 2: home, 3: calendar, 4: my
  const AlarmBottomNavigation({super.key, this.currentIndex = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        color: const Color.fromARGB(255, 252, 252, 252),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AlarmPage()),
                );
              },
              child: SvgPicture.asset(
                currentIndex == 0
                    ? 'assets/images/navicon/alarm_active.svg'
                    : 'assets/images/navicon/alarm_deactive.svg',
                width: 50,
                height: 50,
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFFEBF0FF),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (ctx) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                    );
                  },
                );
              },
              child: SvgPicture.asset(
                currentIndex == 1
                    ? 'assets/images/navicon/fam_active.svg'
                    : 'assets/images/navicon/fam_deactive.svg',
                width: 50,
                height: 50,
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              child: SvgPicture.asset(
                currentIndex == 2
                    ? 'assets/images/navicon/home_active.svg'
                    : 'assets/images/navicon/home_deactive.svg',
                width: 50,
                height: 50,
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const CalendarPage()),
                );
              },
              child: Icon(
                Icons.calendar_today,
                size: 50,
                color: currentIndex == 3 ? Colors.black : Colors.black54,
              ),
            ),
            const SizedBox(width: 40),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // 마이 페이지: 아직 연결된 페이지가 없다면 필요 시 추가
              },
              child: SvgPicture.asset(
                currentIndex == 4
                    ? 'assets/images/navicon/my_active.svg'
                    : 'assets/images/navicon/my_deactive.svg',
                width: 50,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
