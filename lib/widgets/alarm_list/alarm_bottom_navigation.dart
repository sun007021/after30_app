// 이 위젯은 alarm_list.dart(알람 목록 화면)에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:after30/screens/home.dart';
import 'package:after30/screens/alarm_list.dart';

class AlarmBottomNavigation extends StatelessWidget {
  const AlarmBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      backgroundColor: Colors.grey[200],
      currentIndex: 0,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AlarmPage()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.alarm), label: '알람'),
        BottomNavigationBarItem(icon: Icon(Icons.family_restroom), label: '가족'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '달력'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이'),
      ],
    );
  }
}
