// 디버그 전용 알람 UI 프리뷰 엔트리포인트(plan §6 W5 검증 절차).
//
// 실제 화면은 로그인 세션이 있어야 열리므로, Firebase/Kakao/AlarmService를
// 초기화하지 않고 가짜 서비스로 약 등록/알람 목록/풀스크린 알람/시간 휠을
// 바로 띄운다. 릴리스 진입점이 아니므로 `main.dart`에서 import하지 않는다.
//
// 실행: flutter run -d <simulator> -t lib/dev/alarm_ui_preview_main.dart \
//   --dart-define=SCREEN=register|picker|list|swipe|fullscreen
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';

const _screen = String.fromEnvironment('SCREEN', defaultValue: 'list');

class _FakeSchedule implements ScheduleService {
  @override
  Future<List<dynamic>> getSchedules({bool includeInactive = false, int? userId}) async => [
    {
      'id': 1,
      'medication_name': '혈압약',
      'times': ['08:00', '20:00'],
      'repeat_days': ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
      'is_active': true,
    },
    {
      'id': 2,
      'medication_name': '비타민 D',
      'times': ['09:30'],
      'repeat_days': ['MON', 'WED', 'FRI'],
      'is_active': true,
    },
    {
      'id': 3,
      'medication_name': '감기약',
      'times': ['13:00'],
      'repeat_days': ['SAT'],
      'is_active': false,
    },
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAlarm implements AlarmService {
  @override
  Future<bool> hasScheduledNotifications(String alarmId) async => true;

  @override
  Future<bool> scheduleAlarm(MedicineAlarm alarm) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _navKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MaterialApp(
      navigatorKey: _navKey,
      title: '알람 UI 프리뷰',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
      routes: {'/home': (_) => const Scaffold(body: Center(child: Text('home')))},
      home: const _Preview(),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  void initState() {
    super.initState();
    if (_screen == 'swipe') {
      Timer(const Duration(seconds: 2), _swipeFirstRow);
    }
    if (_screen == 'picker') {
      Timer(const Duration(seconds: 1), () {
        final ctx = _navKey.currentContext;
        if (ctx != null) {
          showAppTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 8, minute: 0));
        }
      });
    }
  }

  /// 첫 행을 합성 포인터 이벤트로 왼쪽으로 끌어 삭제 버튼을 연다.
  void _swipeFirstRow() {
    final size = MediaQueryData.fromView(View.of(context)).size;
    final start = Offset(size.width * 0.8, size.height * 0.28);
    const pointer = 7;
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(pointer: pointer, position: start));
    for (var i = 1; i <= 10; i++) {
      binding.handlePointerEvent(
        PointerMoveEvent(pointer: pointer, position: start - Offset(i * 10.0, 0), delta: const Offset(-10, 0)),
      );
    }
    binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: start - const Offset(100, 0)));
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _FakeSchedule();
    final alarm = _FakeAlarm();
    switch (_screen) {
      case 'register':
      case 'picker':
        return MedicineRegisterPage(scheduleService: schedule, alarmService: alarm);
      case 'fullscreen':
        return FullscreenAlarmPage(
          alarm: MedicineAlarm(
            id: '1',
            name: '혈압약',
            times: const [TimeOfDay(hour: 8, minute: 0)],
            days: const ['월'],
          ),
          time: const TimeOfDay(hour: 8, minute: 0),
          day: '월',
          notificationId: 1,
        );
      default:
        return Scaffold(
          backgroundColor: AppColors.groupedBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('등록된 약', style: AppTypography.largeTitle),
                ),
                AlarmContent(scheduleService: schedule, alarmService: alarm),
              ],
            ),
          ),
        );
    }
  }
}
