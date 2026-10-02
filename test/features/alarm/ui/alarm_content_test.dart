import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/alarm/ui/widgets/alarm_card.dart';
import 'package:after30/features/alarm/ui/widgets/empty_alarm_section.dart';

import 'alarm_ui_fakes.dart';

void main() {
  late FakeScheduleService schedule;
  late FakeAlarmService alarms;
  late StreamController<String> warnings;
  late GlobalKey<AlarmContentState> key;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    schedule = FakeScheduleService();
    alarms = FakeAlarmService();
    warnings = StreamController<String>.broadcast();
    key = GlobalKey<AlarmContentState>();
  });

  tearDown(() => warnings.close());

  Future<void> pumpContent(WidgetTester tester, TargetPlatform platform) {
    return pumpAlarmUi(
      tester,
      platform,
      Scaffold(
        body: Column(
          children: [
            AlarmContent(
              key: key,
              scheduleService: schedule,
              alarmService: alarms,
              budgetWarnings: warnings.stream,
            ),
          ],
        ),
      ),
    );
  }

  group('Android 패리티', () {
    testWidgets('기존 위젯 구조: CircularProgressIndicator 로더, 팝업 메뉴, Material Switch', (tester) async {
      final completer = Completer<List<dynamic>>();
      schedule.onGetSchedules = () => completer.future;
      await pumpContent(tester, TargetPlatform.android);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppActivityIndicator), findsNothing);

      completer.complete([scheduleJson(1, '혈압약')]);
      await tester.pumpAndSettle();

      expect(find.byType(AlarmCard), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.byType(AppSwipeActions), findsNothing);
      expect(find.widgetWithText(ElevatedButton, '약 등록하기  +'), findsOneWidget);
      expect(find.text('월 화'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('팝업 메뉴 삭제는 확인 후 서버/기기 삭제를 수행한다', (tester) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      await pumpContent(tester, TargetPlatform.android);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알람 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      expect(schedule.deleted, [1]);
      expect(alarms.deletedLocal, ['1']);
      expect(find.byType(EmptyAlarmSection), findsOneWidget);
    });

    testWidgets('빈 상태는 기존 ElevatedButton 레이아웃을 쓴다', (tester) async {
      await pumpContent(tester, TargetPlatform.android);
      await tester.pumpAndSettle();
      expect(find.byType(EmptyAlarmSection), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('예산 경고는 SnackBar로 보인다(기존 알림 방식과 동일)', (tester) async {
      await pumpContent(tester, TargetPlatform.android);
      await tester.pumpAndSettle();

      warnings.add('알람이 많아 일부는 나중에 예약돼요');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('알람이 많아 일부는 나중에 예약돼요'), findsOneWidget);
    });

    testWidgets('Android 동기화는 누락된 알람만 하나씩 scheduleAlarm 한다', (tester) async {
      schedule.schedules = [
        scheduleJson(1, 'A'),
        scheduleJson(2, 'B'),
        scheduleJson(3, 'C', active: false),
      ];
      alarms.hasSchedule = {'1'};
      await pumpContent(tester, TargetPlatform.android);
      await tester.pumpAndSettle();

      expect(alarms.scheduled.map((a) => a.id), ['2']);
      expect(alarms.synced, isEmpty);
    });
  });

  group('iOS', () {
    testWidgets('로더/스위치/스와이프 삭제 등 적응형 위젯을 쓴다', (tester) async {
      final completer = Completer<List<dynamic>>();
      schedule.onGetSchedules = () => completer.future;
      await pumpContent(tester, TargetPlatform.iOS);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete([scheduleJson(1, '혈압약')]);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(AppSwipeActions), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.text('혈압약'), findsOneWidget);
    });

    testWidgets('빈 상태에서 약 등록하기 CTA를 보여준다', (tester) async {
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();
      expect(find.text('등록된 약이 없어요!'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('스와이프 삭제는 destructive 확인 후에만 삭제한다(취소하면 유지)', (tester) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      await tester.drag(find.text('혈압약'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();

      // CupertinoAlertDialog: destructive 액션
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final destructive = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, '삭제'),
      );
      expect(destructive.isDestructiveAction, isTrue);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '취소'));
      await tester.pumpAndSettle();
      expect(schedule.deleted, isEmpty);
      expect(find.text('혈압약'), findsOneWidget);
    });

    testWidgets('스와이프 삭제 확정 시 서버 삭제 + 기기 취소 + 목록 갱신', (tester) async {
      schedule.schedules = [scheduleJson(1, '혈압약'), scheduleJson(2, '비타민')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      await tester.drag(find.text('혈압약'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '삭제'));
      await tester.pumpAndSettle();

      expect(schedule.deleted, [1]);
      expect(alarms.deletedLocal, ['1']);
      expect(find.text('혈압약'), findsNothing);
      expect(find.text('비타민'), findsOneWidget);
    });

    testWidgets('스위치를 끄면 확인 후 서버 비활성화와 기기 예약 취소를 한다', (tester) async {
      schedule.schedules = [scheduleJson(1, '혈압약')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('중단하기'));
      await tester.pumpAndSettle();

      expect(schedule.deactivated, [1]);
      expect(alarms.toggledOff, ['1']);
      expect(alarms.cancelled, ['1']);
    });

    testWidgets('스위치 동기화 실패 시 되돌리고 AppToast로 알린다', (tester) async {
      schedule.schedules = [scheduleJson(1, '혈압약', active: false)];
      alarms.hasSchedule = {'1'};
      final failing = _FailingActivateSchedule()..schedules = schedule.schedules;
      await pumpAlarmUi(
        tester,
        TargetPlatform.iOS,
        Scaffold(
          body: Column(
            children: [
              AlarmContent(
                key: key,
                scheduleService: failing,
                alarmService: alarms,
                budgetWarnings: warnings.stream,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      expect(find.textContaining('상태 변경 동기화 실패'), findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('예산 경고 스트림 메시지가 AppToast로 보인다', (tester) async {
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      warnings.add('알람이 많아 일부는 나중에 예약돼요');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('알람이 많아 일부는 나중에 예약돼요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('보이지 않는 탭(TickerMode 꺼짐)에서는 토스트를 띄우지 않는다', (tester) async {
      await pumpAlarmUi(
        tester,
        TargetPlatform.iOS,
        TickerMode(
          enabled: false,
          child: Scaffold(
            body: Column(
              children: [
                AlarmContent(
                  scheduleService: schedule,
                  alarmService: alarms,
                  budgetWarnings: warnings.stream,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      warnings.add('보이면 안 되는 메시지');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('보이면 안 되는 메시지'), findsNothing);
    });

    testWidgets('화면이 사라지면 예산 경고 구독을 해제한다', (tester) async {
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();
      expect(warnings.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(warnings.hasListener, isFalse);
    });

    testWidgets('iOS 동기화: 누락된 알람이 여러 개여도 전체 재예약은 한 번만 한다', (tester) async {
      schedule.schedules = [
        scheduleJson(1, 'A'),
        scheduleJson(2, 'B'),
        scheduleJson(3, 'C'),
        scheduleJson(4, 'D', active: false),
      ];
      alarms.hasSchedule = {'1'};
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      expect(alarms.scheduled, isEmpty, reason: '알람마다 scheduleAlarm을 부르면 64개 예산을 매번 재계산한다');
      expect(alarms.synced, hasLength(1));
      // 서버 전체 목록(비활성 포함)을 넘겨 저장소를 서버와 맞춘다.
      expect(alarms.synced.single.map((a) => a.id), ['1', '2', '3', '4']);
    });

    testWidgets('iOS 동기화: 모두 이미 관리 중이면 재예약하지 않는다', (tester) async {
      schedule.schedules = [scheduleJson(1, 'A'), scheduleJson(2, 'B')];
      alarms.hasSchedule = {'1', '2'};
      alarms.stored = [
        MedicineAlarm(id: '1', name: 'A', times: const [TimeOfDay(hour: 8, minute: 0)], days: const ['월', '화']),
        MedicineAlarm(id: '2', name: 'B', times: const [TimeOfDay(hour: 8, minute: 0)], days: const ['월', '화']),
      ];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      expect(alarms.synced, isEmpty);
      expect(alarms.scheduled, isEmpty);
    });
  });

  group('탭 재활성화 / 응답 경쟁', () {
    testWidgets('최초 방문 로딩 중의 활성화 알림은 중복 요청을 만들지 않는다', (tester) async {
      final completer = Completer<List<dynamic>>();
      schedule.onGetSchedules = () => completer.future;
      await pumpContent(tester, TargetPlatform.iOS);
      expect(schedule.getSchedulesCalls, 1);

      await key.currentState!.onTabActivated();
      expect(schedule.getSchedulesCalls, 1);

      completer.complete([scheduleJson(1, 'A')]);
      await tester.pumpAndSettle();
      expect(schedule.getSchedulesCalls, 1);
    });

    testWidgets('이후 활성화는 스피너 없이 다시 불러와 갱신한다', (tester) async {
      schedule.schedules = [scheduleJson(1, 'A')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      schedule.schedules = [scheduleJson(1, 'A'), scheduleJson(2, 'B')];
      final future = key.currentState!.onTabActivated();
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      await future;
      await tester.pumpAndSettle();

      expect(schedule.getSchedulesCalls, 2);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('느린 이전 응답이 최신 응답을 덮어쓰지 않는다', (tester) async {
      schedule.schedules = [scheduleJson(1, 'A')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      final slow = Completer<List<dynamic>>();
      final fast = Completer<List<dynamic>>();
      final queue = [slow, fast];
      schedule.onGetSchedules = () => queue.removeAt(0).future;

      final first = key.currentState!.onTabActivated();
      final second = key.currentState!.onTabActivated();
      fast.complete([scheduleJson(9, 'NEW')]);
      await second;
      await tester.pumpAndSettle();
      expect(find.text('NEW'), findsOneWidget);

      slow.complete([scheduleJson(8, 'OLD')]);
      await first;
      await tester.pumpAndSettle();
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('OLD'), findsNothing);
    });

    testWidgets('화면이 사라진 뒤 도착한 응답은 무시한다(mounted 가드)', (tester) async {
      schedule.schedules = [scheduleJson(1, 'A')];
      await pumpContent(tester, TargetPlatform.iOS);
      await tester.pumpAndSettle();

      final late = Completer<List<dynamic>>();
      schedule.onGetSchedules = () => late.future;
      final pending = key.currentState!.onTabActivated();
      await tester.pumpWidget(const SizedBox());
      late.complete([scheduleJson(2, 'B')]);
      await pending;
      expect(tester.takeException(), isNull);
    });
  });
}

class _FailingActivateSchedule extends FakeScheduleService {
  @override
  Future<dynamic> activateSchedule(int scheduleId) async {
    throw Exception('network');
  }
}
