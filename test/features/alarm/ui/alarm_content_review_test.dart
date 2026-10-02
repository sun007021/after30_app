import 'dart:async';

import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';

import 'alarm_ui_fakes.dart';

/// 지연/실패를 제어할 수 있는 서버 가짜.
class GatedSchedule extends FakeScheduleService {
  Completer<void>? deleteGate;
  Completer<void>? activateGate;
  bool failDelete = false;
  final List<String> calls = [];

  @override
  Future<void> deleteSchedule(int scheduleId) async {
    calls.add('delete:$scheduleId');
    await deleteGate?.future;
    if (failDelete) throw Exception('404');
    return super.deleteSchedule(scheduleId);
  }

  @override
  Future<dynamic> activateSchedule(int scheduleId) async {
    calls.add('activate:$scheduleId');
    await activateGate?.future;
    return super.activateSchedule(scheduleId);
  }

  @override
  Future<dynamic> deactivateSchedule(int scheduleId) async {
    calls.add('deactivate:$scheduleId');
    return super.deactivateSchedule(scheduleId);
  }
}

class GatedAlarm extends FakeAlarmService {
  Completer<void>? hasGate;

  @override
  Future<bool> hasScheduledNotifications(String alarmId) async {
    await hasGate?.future;
    return hasSchedule.contains(alarmId);
  }
}

MedicineAlarm alarmOf(String id, {bool active = true}) => MedicineAlarm(
  id: id,
  name: '약$id',
  times: const [TimeOfDay(hour: 8, minute: 0)],
  days: const ['월', '화'],
  isActive: active,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const awesomeChannel = MethodChannel('awesome_notifications');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late GatedSchedule schedule;
  late GatedAlarm alarms;
  late GlobalKey<AlarmContentState> key;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    schedule = GatedSchedule();
    alarms = GatedAlarm();
    key = GlobalKey<AlarmContentState>();
  });

  Future<void> pump(WidgetTester t, TargetPlatform p, {AlarmService? service}) => pumpAlarmUi(
    t,
    p,
    Scaffold(
      body: Column(
        children: [
          AlarmContent(
            key: key,
            scheduleService: schedule,
            alarmService: service ?? alarms,
            budgetWarnings: const Stream<String>.empty(),
          ),
        ],
      ),
    ),
  );

  Finder iosSwitch() => find.byType(CupertinoSwitch);

  group('삭제 중복/낙관적 삭제', () {
    testWidgets('느린 서버 삭제 중에도 카드가 즉시 사라져 같은 삭제를 두 번 보낼 수 없다', (t) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      schedule.deleteGate = Completer<void>();
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      await t.drag(find.text('혈압약'), const Offset(-150, 0));
      await t.pumpAndSettle();
      await t.tap(find.text('삭제').last);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(CupertinoDialogAction, '삭제'));
      await t.pumpAndSettle();

      expect(find.text('혈압약'), findsNothing, reason: '낙관적 삭제');
      // 진행 중에 활성화 알림으로 재조회돼도 지워지는 중인 카드가 되살아나지 않는다.
      await key.currentState!.onTabActivated();
      await t.pumpAndSettle();
      expect(find.text('혈압약'), findsNothing);

      schedule.deleteGate!.complete();
      await t.pumpAndSettle();
      expect(schedule.calls.where((c) => c.startsWith('delete')), ['delete:1']);
      expect(alarms.deletedLocal, ['1']);
    });

    testWidgets('서버 삭제가 실패하면 카드를 원래 자리에 되돌리고 토스트로 알린다', (t) async {
      schedule.schedules = [scheduleJson(1, 'A'), scheduleJson(2, 'B'), scheduleJson(3, 'C')];
      schedule.failDelete = true;
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      await t.drag(find.text('B'), const Offset(-150, 0));
      await t.pumpAndSettle();
      await t.tap(find.text('삭제').at(1));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(CupertinoDialogAction, '삭제'));
      await t.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);
      expect(find.textContaining('서버 삭제 실패'), findsOneWidget);
      expect(alarms.deletedLocal, isEmpty);
      final order = ['A', 'B', 'C'].map((n) => t.getTopLeft(find.text(n)).dy).toList();
      expect(order, [...order]..sort());
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
    });
  });

  group('토글 경합', () {
    testWidgets('켜는 중(느린 activate)에 다시 눌러도 deactivate를 동시에 보내지 않는다', (t) async {
      schedule.schedules = [scheduleJson(1, '혈압약', active: false)];
      schedule.activateGate = Completer<void>();
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      await t.tap(iosSwitch());
      await t.pump();
      await t.tap(iosSwitch());
      await t.pumpAndSettle();
      expect(find.text('복용을 중단하시겠습니까?'), findsNothing);

      schedule.activateGate!.complete();
      await t.pumpAndSettle();
      expect(schedule.calls, ['activate:1']);
      expect(alarms.scheduled.single.isActive, isTrue);
      expect(alarms.toggledOff, isEmpty);
    });
  });

  group('동기화 pass', () {
    testWidgets('동기화 중 새로 도착한 목록의 누락 알람도 끝난 뒤 한 번 더 처리한다', (t) async {
      schedule.schedules = [scheduleJson(1, 'A')];
      alarms.hasGate = Completer<void>();
      await pump(t, TargetPlatform.android);
      await t.pumpAndSettle();

      schedule.schedules = [scheduleJson(1, 'A'), scheduleJson(2, 'B')];
      await key.currentState!.onTabActivated();
      await t.pumpAndSettle();
      alarms.hasGate!.complete();
      await t.pumpAndSettle();

      expect(alarms.scheduled.map((a) => a.id).toSet(), {'1', '2'});
    });

    testWidgets('iOS: 다른 기기에서 삭제된 알람이 저장소에 남아 있으면 누락이 없어도 정리한다', (t) async {
      schedule.schedules = [scheduleJson(1, 'A')];
      alarms.hasSchedule = {'1'};
      alarms.stored = [alarmOf('1'), alarmOf('9')];
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      expect(alarms.synced, hasLength(1));
      expect(alarms.synced.single.map((a) => a.id), ['1']);
    });
  });

  group('스와이프 행 탭', () {
    testWidgets('열린 행의 본문을 탭하면 수정 화면 대신 행만 닫힌다', (t) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      final before = t.getTopLeft(find.text('혈압약')).dx;
      await t.drag(find.text('혈압약'), const Offset(-150, 0));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text('혈압약')).dx, lessThan(before));

      await t.tap(find.text('혈압약'), warnIfMissed: false);
      await t.pumpAndSettle();

      expect(find.text('약 수정'), findsNothing);
      expect(t.getTopLeft(find.text('혈압약')).dx, before);
    });

    testWidgets('닫힌 행의 본문을 탭하면 수정 화면이 열리고 스위치 탭은 수정으로 가지 않는다', (t) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      await pump(t, TargetPlatform.iOS);
      await t.pumpAndSettle();

      await t.tap(iosSwitch());
      await t.pumpAndSettle();
      await t.tap(find.text('중단하기'));
      await t.pumpAndSettle();
      expect(find.text('약 수정'), findsNothing);

      await t.tap(find.text('혈압약'));
      await t.pumpAndSettle();
      expect(find.text('약 수정'), findsOneWidget);
    });
  });

  group('실제 AlarmService 저장소(테스트 호스트 = Android 경로)', () {
    setUp(() {
      AwesomeNotificationsPlatform.operatingSystem = 'android';
      AwesomeNotificationsPlatform.resetInstance();
      messenger.setMockMethodCallHandler(awesomeChannel, (call) async => true);
      AlarmService.setCurrentUserId('u1');
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(awesomeChannel, null);
      AlarmService.setCurrentUserId(null);
    });

    Future<Map<String, bool>> stored() async {
      final list = await AlarmService().getAlarms();
      return {for (final a in list) a.id: a.isActive};
    }

    Future<void> seed(WidgetTester t, List<MedicineAlarm> list) async {
      await t.runAsync(() async {
        for (final a in list) {
          await AlarmService().scheduleAlarm(a);
        }
      });
    }

    testWidgets('UI에서 삭제하면 저장소에서도 사라진다(재시작/복귀 시 재예약 방지)', (t) async {
      await seed(t, [alarmOf('1')]);
      schedule.schedules = [scheduleJson(1, '약1')];
      await pump(t, TargetPlatform.android, service: AlarmService());
      await t.pumpAndSettle();

      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('알람 삭제'));
      await t.pumpAndSettle();
      await t.tap(find.text('삭제'));
      await t.pumpAndSettle();

      expect(await t.runAsync(stored), isEmpty);
    });

    testWidgets('UI에서 끄면 저장소 isActive=false, 다시 켜면 true로 저장된다', (t) async {
      await seed(t, [alarmOf('1')]);
      schedule.schedules = [scheduleJson(1, '약1')];
      await pump(t, TargetPlatform.android, service: AlarmService());
      await t.pumpAndSettle();

      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      await t.tap(find.text('중단하기'));
      await t.pumpAndSettle();
      expect(await t.runAsync(stored), {'1': false});

      schedule.schedules = [scheduleJson(1, '약1', active: false)];
      await key.currentState!.onTabActivated();
      await t.pumpAndSettle();
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(await t.runAsync(stored), {'1': true});
    });
  });

  group('AlarmService.syncFromServer', () {
    final created = <int>[];

    setUp(() {
      created.clear();
      AwesomeNotificationsPlatform.operatingSystem = 'android';
      AwesomeNotificationsPlatform.resetInstance();
      messenger.setMockMethodCallHandler(awesomeChannel, (call) async {
        if (call.method == 'createNewNotification') {
          created.add(((call.arguments as Map)['content'] as Map)['id'] as int);
        }
        return true;
      });
      AlarmService.setCurrentUserId('u1');
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(awesomeChannel, null);
      AlarmService.setCurrentUserId(null);
    });

    Future<Map<String, bool>> stored() async => {
      for (final a in await AlarmService().getAlarms()) a.id: a.isActive,
    };

    test('서버에 없는 알람은 제거하고 비활성은 서버 값을 따르며 알림 id는 보존한다', () async {
      await AlarmService().scheduleAlarm(alarmOf('9')); // 다른 기기에서 삭제
      await AlarmService().scheduleAlarm(alarmOf('1')); // 다른 기기에서 비활성화
      final prefs = await SharedPreferences.getInstance();
      final idsBefore = prefs.getStringList('notification_ids_u1_1');
      expect(idsBefore, isNotEmpty);

      await AlarmService().syncFromServer([alarmOf('1', active: false), alarmOf('2')]);

      expect(await stored(), {'1': false, '2': true});
      // 네임스페이스: 사용자별 키에 저장된다(레거시 키 아님).
      expect(prefs.getString('medicine_alarms_u1'), isNotNull);
      expect(prefs.getStringList('notification_ids_u1_1'), idsBefore);
    });

    test('활성 알람만 한 번에 예약한다(알람 2개 = 알림 생성은 해당 알람 것만)', () async {
      await AlarmService().syncFromServer([alarmOf('1'), alarmOf('2'), alarmOf('3', active: false)]);

      expect(await stored(), {'1': true, '2': true, '3': false});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('notification_ids_u1_1'), isNotEmpty);
      expect(prefs.getStringList('notification_ids_u1_2'), isNotEmpty);
      expect(prefs.getStringList('notification_ids_u1_3'), anyOf(isNull, isEmpty));
    });

    test('로컬 전용 값(nfcEnabled)은 보존한다', () async {
      await AlarmService().scheduleAlarm(alarmOf('1').copyWith(nfcEnabled: true));
      await AlarmService().syncFromServer([alarmOf('1')]);
      final list = await AlarmService().getAlarms();
      expect(list.single.nfcEnabled, isTrue);
    });
  });
}
