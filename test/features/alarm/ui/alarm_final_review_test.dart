import 'dart:async';

import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';

import 'alarm_ui_fakes.dart';

/// PR #36 최종 리뷰 회귀 테스트(F2 VoiceOver 탭, F4 삭제 알람 키 정리, F5 역방향 동기화).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const awesomeChannel = MethodChannel('awesome_notifications');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Widget host(FakeScheduleService s, AlarmService a, {Key? key}) => Scaffold(
    body: Column(children: [
      AlarmContent(key: key, scheduleService: s, alarmService: a, budgetWarnings: const Stream.empty()),
    ]),
  );

  testWidgets('F2 (m-3 접근성) iOS: VoiceOver 탭(SemanticsAction.tap)으로 카드 수정 화면이 열리는가', (t) async {
    SharedPreferences.setMockInitialValues({});
    final handle = t.ensureSemantics();
    final s = FakeScheduleService()..schedules = [scheduleJson(1, '혈압약')];
    await pumpAlarmUi(t, TargetPlatform.iOS, host(s, FakeAlarmService()));
    await t.pumpAndSettle();
    final node = t.getSemantics(find.text('혈압약'));
    // 탭 액션을 가진 가장 가까운 조상 노드를 찾는다.
    SemanticsNode? n = node;
    while (n != null && !n.getSemanticsData().hasAction(SemanticsAction.tap)) {
      n = n.parent;
    }
    debugPrint('F2 tapNode=${n?.id} label="${n?.label}" customActions=${node.getSemanticsData().customSemanticsActionIds}');
    if (n != null) {
      n.owner!.performAction(n.id, SemanticsAction.tap);
      await t.pumpAndSettle();
    }
    final editOpened = find.text('약 수정').evaluate().isNotEmpty;
    debugPrint('F2 editOpenedBySemanticsTap=$editOpened');
    handle.dispose();
    expect(editOpened, isTrue, reason: 'VoiceOver 사용자는 iOS에서 카드 수정에 들어갈 방법이 없다');
  });

  group('실제 AlarmService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AwesomeNotificationsPlatform.operatingSystem = 'android';
      AwesomeNotificationsPlatform.resetInstance();
      messenger.setMockMethodCallHandler(awesomeChannel, (call) async => true);
      AlarmService.setCurrentUserId('u1');
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(awesomeChannel, null);
      AlarmService.setCurrentUserId(null);
    });

    MedicineAlarm a(String id, {bool active = true}) => MedicineAlarm(
      id: id, name: '약$id', times: const [TimeOfDay(hour: 8, minute: 0)], days: ['월', '화'], isActive: active);

    Future<Map<String, bool>> stored() async =>
        {for (final x in await AlarmService().getAlarms()) x.id: x.isActive};

    test('F4 (m-4) syncFromServer: 삭제/비활성 반영, 네임스페이스 키, 삭제된 알람 id 키 처리', () async {
      await AlarmService().scheduleAlarm(a('9'));
      await AlarmService().scheduleAlarm(a('1'));
      final prefs = await SharedPreferences.getInstance();
      final ids1 = prefs.getStringList('notification_ids_u1_1');
      await AlarmService().syncFromServer([a('1', active: false), a('2')]);
      debugPrint('F4 stored=${await stored()} legacyKey=${prefs.getString('medicine_alarms')} '
          'ids1 before=$ids1 after=${prefs.getStringList('notification_ids_u1_1')} '
          'ids9(서버에서 삭제됨)=${prefs.getStringList('notification_ids_u1_9')}');
      expect(await stored(), {'1': false, '2': true});
      expect(prefs.getStringList('notification_ids_u1_9'), isNull, reason: '서버에서 삭제된 알람의 알림 id 키는 지운다');
      expect(prefs.getStringList('notification_ids_u1_1'), ids1, reason: '남은 알람의 알림 id는 보존한다');
    });

    testWidgets('F5 (m-4 역방향) iOS 목록: 이 기기에서 끈 알람을 다른 기기에서 켜면 저장소가 서버 값을 따르는가', (t) async {
      await t.runAsync(() async {
        await AlarmService().scheduleAlarm(a('1'));
        // 이 기기에서 중단(목록 UI의 중단 경로와 같은 호출).
        await AlarmService().toggleAlarm('1', false);
        await AlarmService().cancelAlarm('1');
      });
      final before = await t.runAsync(stored);
      final has = await t.runAsync(() => AlarmService().hasScheduledNotifications('1'));
      // 서버: 다른 기기에서 다시 켬.
      final s = FakeScheduleService()..schedules = [scheduleJson(1, '약1', active: true)];
      await pumpAlarmUi(t, TargetPlatform.iOS, host(s, AlarmService()));
      await t.pumpAndSettle();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await t.pumpAndSettle();
      final after = await t.runAsync(stored);
      final uiOn = t.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value;
      debugPrint('F5 before=$before hasScheduled(inactive)=$has uiSwitchOn=$uiOn storedAfterSync=$after');
      expect(after!['1'], isTrue, reason: '서버는 활성인데 저장소는 비활성으로 남아 기기에서 울리지 않는다');
    });
  });
}
