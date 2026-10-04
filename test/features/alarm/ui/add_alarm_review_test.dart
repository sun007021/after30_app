import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';

import 'alarm_ui_fakes.dart';

class GatedSchedule extends FakeScheduleService {
  Completer<void>? gate;
  int updates = 0;

  @override
  Future<dynamic> createSchedule(Map<String, dynamic> body) async {
    created.add(body);
    await gate?.future;
    return {'id': nextId++};
  }

  @override
  Future<dynamic> updateSchedule(int scheduleId, Map<String, dynamic> body) async {
    updates++;
    return super.updateSchedule(scheduleId, body);
  }
}

void main() {
  late GatedSchedule schedule;
  late FakeAlarmService alarms;
  late FakeGate gate;
  Object? popped;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    schedule = GatedSchedule();
    alarms = FakeAlarmService();
    gate = FakeGate();
    popped = null;
  });

  Future<void> open(WidgetTester t, TargetPlatform p, {MedicineAlarm? initial}) => pumpPushedPage(
    t,
    p,
    MedicineRegisterPage(
      initialAlarm: initial,
      scheduleService: schedule,
      alarmService: alarms,
      permissionGate: gate,
    ),
    onResult: (r) => popped = r,
  );

  Finder nameField(TargetPlatform p) =>
      p == TargetPlatform.iOS ? find.byType(CupertinoTextField) : find.byType(TextField).first;

  Future<void> fill(WidgetTester t, TargetPlatform p) async {
    await t.enterText(nameField(p), '혈압약');
    await t.tap(find.text('월'));
    await t.pump();
  }

  Future<void> submit(WidgetTester t) async {
    await t.tap(find.text('등록하기'));
    await t.pumpAndSettle();
    await t.tap(find.text('등록'));
    await t.pumpAndSettle();
  }

  group('권한: 실제 시스템 상태 기준(iOS)', () {
    testWidgets('이미 허용된 사용자에게는 사전 설명을 보여주지 않고 AlarmKit만 확인한다', (t) async {
      gate.current = NotificationAuthorizationStatus.authorized;
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await submit(t);

      expect(gate.requestCalls, 0);
      expect(gate.alarmKitCalls, 1);
      expect(find.textContaining('알람이 울리지 않아요'), findsNothing);
      expect(popped, isA<MedicineAlarm>());
    });

    testWidgets('예전에 허용했더라도 설정에서 꺼졌다면 저장 후 설정 열기를 안내한다', (t) async {
      // 이전 버전이 남긴 "허용 완료" 플래그가 있어도 실제 상태가 우선이다.
      SharedPreferences.setMockInitialValues({'alarm_permission_rationale_done': true});
      gate.current = NotificationAuthorizationStatus.denied;
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await t.tap(find.text('등록하기'));
      await t.pumpAndSettle();
      await t.tap(find.text('등록'));
      await t.pumpAndSettle();

      expect(gate.requestCalls, 0, reason: '거부 상태는 시스템 프롬프트를 다시 띄울 수 없다');
      expect(schedule.created, hasLength(1));
      expect(find.text('알림이 꺼져 있어요'), findsOneWidget);
      await t.tap(find.text('설정 열기'));
      await t.pumpAndSettle();
      expect(gate.settingsCalls, 1);
      expect(popped, isA<MedicineAlarm>());
    });

    testWidgets('거부 상태에서 "나중에"를 누르면 토스트로 알리고 등록은 유지된다', (t) async {
      gate.current = NotificationAuthorizationStatus.denied;
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await submit(t);
      await t.tap(find.text('나중에'));
      await t.pumpAndSettle();

      expect(gate.settingsCalls, 0);
      expect(find.textContaining('알람이 울리지 않아요'), findsOneWidget);
      expect(popped, isA<MedicineAlarm>());
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
    });

    testWidgets('미결정이면 사전 설명 후 요청하고, 사용자가 미루면 토스트 + 다음에 다시 묻는다', (t) async {
      gate.grantOnRequest = false;
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await submit(t);
      await t.pump(const Duration(milliseconds: 300));

      expect(gate.requestCalls, 1);
      expect(find.textContaining('알람이 울리지 않아요'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await fill(t, TargetPlatform.iOS);
      await submit(t);
      expect(gate.requestCalls, 2);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
    });

    testWidgets('Android는 권한 창구를 전혀 호출하지 않는다', (t) async {
      await open(t, TargetPlatform.android);
      await fill(t, TargetPlatform.android);
      await submit(t);

      expect(gate.events, isEmpty);
      expect(popped, isA<MedicineAlarm>());
    });
  });

  group('중복 제출 / 서버 스케줄 중복', () {
    testWidgets('Android: 느린 생성 중에 등록하기를 다시 눌러도 두 번째 확인창/생성이 없다', (t) async {
      schedule.gate = Completer<void>();
      await open(t, TargetPlatform.android);
      await fill(t, TargetPlatform.android);

      await t.tap(find.byType(ElevatedButton));
      await t.pumpAndSettle();
      await t.tap(find.text('등록'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.byType(ElevatedButton));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('약을 등록하시겠습니까?'), findsNothing);

      schedule.gate!.complete();
      await t.pumpAndSettle();
      expect(schedule.created, hasLength(1));
      expect(alarms.scheduled, hasLength(1));
    });

    testWidgets('확인창이 떠 있는 동안 등록하기를 다시 눌러도 확인창이 하나만 뜬다', (t) async {
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await t.tap(find.text('등록하기'));
      await t.tap(find.text('등록하기'), warnIfMissed: false);
      await t.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await t.tap(find.text('등록'));
      await t.pumpAndSettle();
      expect(schedule.created, hasLength(1));
    });

    testWidgets('기기 예약이 실패한 뒤 다시 시도해도 서버 스케줄은 새로 만들지 않고 갱신한다', (t) async {
      alarms.scheduleResult = false;
      await open(t, TargetPlatform.iOS);
      await fill(t, TargetPlatform.iOS);
      await submit(t);
      expect(find.text('알람 등록에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
      await t.tap(find.text('확인'));
      await t.pumpAndSettle();

      alarms.scheduleResult = true;
      await submit(t);

      expect(schedule.created, hasLength(1), reason: '서버 스케줄 중복 생성 금지');
      expect(schedule.updates, 1);
      expect(alarms.scheduled, hasLength(2));
      expect(alarms.scheduled.last.id, alarms.scheduled.first.id);
      expect(popped, isA<MedicineAlarm>());
    });
  });

  group('수정 화면', () {
    testWidgets('요일을 바꿔도 저장하지 않으면 원본 알람 객체가 바뀌지 않는다', (t) async {
      final initial = MedicineAlarm(
        id: '3',
        name: '기존약',
        times: const [TimeOfDay(hour: 9, minute: 0)],
        days: ['월', '수'],
      );
      await open(t, TargetPlatform.iOS, initial: initial);
      await t.tap(find.text('화'));
      await t.pump();
      expect(initial.days, ['월', '수']);
      expect(initial.times, hasLength(1));
    });

    testWidgets('수정 저장은 start_date를 보내지 않고 중복 시간을 제거/정렬한다', (t) async {
      final initial = MedicineAlarm(
        id: '3',
        name: '기존약',
        times: const [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 9, minute: 0)],
        days: ['월', '수'],
      );
      await open(t, TargetPlatform.iOS, initial: initial);
      await t.tap(find.text('등록하기'));
      await t.pumpAndSettle();
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();

      expect(schedule.updatedBody!.containsKey('start_date'), isFalse);
      expect(schedule.updatedBody!['times'], ['07:00', '09:00']);
      expect(gate.events, isEmpty);
    });

    testWidgets('같은 시각이 두 번 있어도 시간 행 키가 겹치지 않는다', (t) async {
      final initial = MedicineAlarm(
        id: '3',
        name: '기존약',
        times: const [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 9, minute: 0)],
        days: ['월'],
      );
      await open(t, TargetPlatform.iOS, initial: initial);
      expect(find.text('09:00'), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });
  });

  group('Android 패리티(값 비교)', () {
    testWidgets('오류 알럿은 기존 Material AlertDialog(흰 배경, TextButton 확인, 바깥 탭으로 닫힘)', (t) async {
      alarms.scheduleResult = false;
      await open(t, TargetPlatform.android);
      await fill(t, TargetPlatform.android);
      await submit(t);

      final dialog = t.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, Colors.white);
      expect(dialog.shape, isNull, reason: 'showAppAlert의 radius 16 모양이 아니다');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(ElevatedButton)), findsNothing);
      // 기본 barrierDismissible=true, 기본 barrier 색.
      final barrier = t.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(barrier.dismissible, isTrue);
      expect(barrier.color, isNot(const Color(0x80C8C8C8)));
    });

    testWidgets('등록 버튼/요일 토글/체크박스는 기존 색과 모양 값을 유지한다', (t) async {
      await open(t, TargetPlatform.android);

      final button = t.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = button.style!;
      expect(style.backgroundColor!.resolve({}), const Color(0xFF235DFF));
      expect(style.minimumSize!.resolve({}), const Size.fromHeight(48));
      final shape = style.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(8));

      expect(t.widget<Checkbox>(find.byType(Checkbox)).activeColor, const Color(0xFF235DFF));

      final toggle = t.widget<Container>(
        find.ancestor(of: find.text('월'), matching: find.byType(Container)).first,
      );
      final deco = toggle.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(deco.color, Colors.white);
      expect((deco.border! as Border).top.color, const Color(0xFF235DFF));
      expect((deco.border! as Border).top.width, 2);

      final nameInput = t.widget<TextField>(find.byType(TextField).first);
      expect(nameInput.decoration!.fillColor, Colors.grey[200]);
      expect(nameInput.decoration!.border, isA<OutlineInputBorder>());
    });
  });
}

