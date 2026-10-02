import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

/// 알람 UI 테스트 공용 가짜 서비스/헬퍼. 네트워크/채널을 쓰지 않는다.
class FakeScheduleService implements ScheduleService {
  final List<Map<String, dynamic>> created = [];
  final List<int> deleted = [];
  final List<int> deactivated = [];
  final List<int> activated = [];
  Map<String, dynamic>? updatedBody;
  int nextId = 7;

  /// 호출마다 소비되는 `getSchedules` 응답. 비면 [schedules]를 돌려준다.
  List<dynamic> schedules = [];
  int getSchedulesCalls = 0;
  Future<List<dynamic>> Function()? onGetSchedules;

  @override
  Future<dynamic> createSchedule(Map<String, dynamic> body) async {
    created.add(body);
    return {'id': nextId};
  }

  @override
  Future<dynamic> updateSchedule(int scheduleId, Map<String, dynamic> body) async {
    updatedBody = body;
    return {'id': scheduleId};
  }

  @override
  Future<List<dynamic>> getSchedules({bool includeInactive = false, int? userId}) async {
    getSchedulesCalls++;
    if (onGetSchedules != null) return onGetSchedules!();
    return schedules;
  }

  @override
  Future<void> deleteSchedule(int scheduleId) async => deleted.add(scheduleId);

  @override
  Future<dynamic> deactivateSchedule(int scheduleId) async {
    deactivated.add(scheduleId);
    return {};
  }

  @override
  Future<dynamic> activateSchedule(int scheduleId) async {
    activated.add(scheduleId);
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAlarmService implements AlarmService {
  final List<MedicineAlarm> scheduled = [];
  final List<String> cancelled = [];
  final List<List<MedicineAlarm>> synced = [];
  bool scheduleResult = true;

  /// 기기에 이미 예약돼 있다고 답할 알람 id들.
  Set<String> hasSchedule = {};

  @override
  Future<bool> scheduleAlarm(MedicineAlarm alarm) async {
    scheduled.add(alarm);
    return scheduleResult;
  }

  @override
  Future<bool> hasScheduledNotifications(String alarmId) async => hasSchedule.contains(alarmId);

  @override
  Future<void> cancelAlarm(String alarmId) async => cancelled.add(alarmId);

  @override
  Future<void> syncActiveAlarms(List<MedicineAlarm> activeAlarms) async {
    synced.add(List.of(activeAlarms));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 지정 플랫폼 테마로 [child]를 감싼 앱을 띄운다. 큰 화면 크기를 쓴다.
Future<void> pumpAlarmUi(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child, {
  Size size = const Size(600, 1000),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: child,
    ),
  );
}

/// 홈 위에 [page]를 push하는 앱. `Navigator.pop(result)`를 검증할 수 있다.
Future<void> pumpPushedPage(
  WidgetTester tester,
  TargetPlatform platform,
  Widget page, {
  void Function(Object? result)? onResult,
}) async {
  await pumpAlarmUi(
    tester,
    platform,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              final r = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
              onResult?.call(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
