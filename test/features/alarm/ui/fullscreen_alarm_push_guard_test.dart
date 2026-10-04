import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/fullscreen_alarm_page.dart';

void main() {
  MedicineAlarm alarmOf(String id) => MedicineAlarm(
    id: id,
    name: '혈압약',
    times: const [TimeOfDay(hour: 8, minute: 0)],
    days: const ['월'],
  );

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    return tester.element(find.byType(Scaffold));
  }

  const time = TimeOfDay(hour: 8, minute: 0);

  testWidgets('같은 알람이 이미 떠 있으면 풀스크린을 중복으로 push하지 않는다', (tester) async {
    final context = await pumpHost(tester);

    AlarmService.showFullscreenAlarm(context, alarmOf('a1'), time, '월');
    await tester.pump(const Duration(milliseconds: 500));
    AlarmService.showFullscreenAlarm(context, alarmOf('a1'), time, '월');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FullscreenAlarmPage, skipOffstage: false), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenAlarmPage), findsNothing);
  });

  testWidgets('닫힌 뒤에는 같은 알람도 다시 띄울 수 있다', (tester) async {
    final context = await pumpHost(tester);

    AlarmService.showFullscreenAlarm(context, alarmOf('a2'), time, '월');
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    AlarmService.showFullscreenAlarm(context, alarmOf('a2'), time, '월');
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenAlarmPage), findsOneWidget);
  });
}
