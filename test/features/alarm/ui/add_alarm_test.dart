import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';

import 'alarm_ui_fakes.dart';

void main() {
  late FakeScheduleService schedule;
  late FakeAlarmService alarms;
  late int permissionCalls;
  late bool permissionResult;
  Object? popped;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    schedule = FakeScheduleService();
    alarms = FakeAlarmService();
    permissionCalls = 0;
    permissionResult = true;
    popped = null;
  });

  Future<void> openPage(
    WidgetTester tester,
    TargetPlatform platform, {
    MedicineAlarm? initial,
  }) {
    return pumpPushedPage(
      tester,
      platform,
      MedicineRegisterPage(
        initialAlarm: initial,
        scheduleService: schedule,
        alarmService: alarms,
        requestPermission: (context) async {
          permissionCalls++;
          return permissionResult;
        },
      ),
      onResult: (r) => popped = r,
    );
  }

  Future<void> register(WidgetTester tester, {String confirm = '등록'}) async {
    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(confirm));
    await tester.pumpAndSettle();
  }

  group('Android 패리티', () {
    testWidgets('기존 위젯 구조: 전체선택 Checkbox, 읽기 전용 알람 행, ElevatedButton', (tester) async {
      await openPage(tester, TargetPlatform.android);

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('전체선택'), findsOneWidget);
      expect(find.byKey(const ValueKey('everyDayChip')), findsNothing);
      expect(find.byType(AppNavBar), findsNothing);
      expect(find.byType(AppTextField), findsNothing);
      expect(find.byType(CupertinoTextField), findsNothing);
      expect(find.byType(AppSwipeActions), findsNothing);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('알람 08:00'), findsOneWidget);
      expect(find.byTooltip('이 시간 삭제'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Checkbox가 전체 요일을 토글하고 등록 시 권한 흐름은 호출하지 않는다', (tester) async {
      await openPage(tester, TargetPlatform.android);

      await tester.enterText(find.byType(TextField).first, '비타민');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await register(tester);

      expect(schedule.created.single['repeat_days'], hasLength(7));
      expect(permissionCalls, 0);
      expect(popped, isA<MedicineAlarm>());
    });

    testWidgets('시간이 하나뿐이면 삭제 대신 안내 알럿이 뜬다', (tester) async {
      await openPage(tester, TargetPlatform.android);

      await tester.tap(find.byTooltip('이 시간 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('복용 시간은 최소 1개 이상 입력해야 합니다.'), findsOneWidget);
      expect(find.text('알람 08:00'), findsOneWidget);
    });

    testWidgets('시간 추가는 마지막 시간 + 1시간을 추가한다', (tester) async {
      await openPage(tester, TargetPlatform.android);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('알람 09:00'), findsOneWidget);
    });
  });

  group('iOS', () {
    testWidgets('네비게이션 바, AppTextField, 매일 칩이 있고 Checkbox는 없다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      expect(find.byType(AppNavBar), findsOneWidget);
      expect(find.text('약 등록'), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('everyDayChip')), findsOneWidget);
      expect(find.byType(AppGroupedSection), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.text('0/255'), findsOneWidget);
    });

    testWidgets('약 이름 입력 글자 수 카운터가 갱신되고 255자로 제한된다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.enterText(find.byType(CupertinoTextField), '타이레놀');
      await tester.pump();
      expect(find.text('4/255'), findsOneWidget);

      final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
      expect(field.maxLength, 255);
    });

    testWidgets('"매일" 칩이 7개 요일을 모두 켜고 다시 누르면 모두 끈다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.enterText(find.byType(CupertinoTextField), '비타민');
      await tester.tap(find.byKey(const ValueKey('everyDayChip')));
      await tester.pump();
      await register(tester);

      expect(schedule.created.single['repeat_days'], hasLength(7));
    });

    testWidgets('"매일" 칩을 두 번 누르면 요일이 비어 입력 누락 안내가 뜬다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.enterText(find.byType(CupertinoTextField), '비타민');
      await tester.tap(find.byKey(const ValueKey('everyDayChip')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('everyDayChip')));
      await tester.pump();
      await tester.tap(find.text('등록하기'));
      await tester.pumpAndSettle();

      expect(find.text('아직 입력되지 않은 정보가 있어요.'), findsOneWidget);
      expect(schedule.created, isEmpty);
    });

    testWidgets('개별 요일을 7개 모두 누르면 매일 칩과 같은 결과가 된다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.enterText(find.byType(CupertinoTextField), '비타민');
      for (final d in ['월', '화', '수', '목', '금', '토', '일']) {
        await tester.tap(find.text(d));
      }
      await tester.pump();
      await register(tester);
      expect(schedule.created.single['repeat_days'], hasLength(7));
    });

    testWidgets('시간 행을 누르면 휠 피커가 열리고 선택값이 적용된다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      expect(find.text('08:00'), findsOneWidget);
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      // 첫 번째 휠(시)을 위로 돌려 8시에서 10시로 만든다.
      await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -96));
      await tester.pumpAndSettle();
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(find.text('08:00'), findsNothing);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('시간 추가 행이 마지막 시간 + 1시간을 목록에 추가한다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.tap(find.text('시간 추가'));
      await tester.pump();
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('스와이프 삭제: 두 개 이상이면 삭제되고 마지막 하나는 최소 1개 규칙으로 막힌다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);

      await tester.tap(find.text('시간 추가'));
      await tester.pump();
      expect(find.text('09:00'), findsOneWidget);

      // 09:00 행을 왼쪽으로 열어 삭제 버튼을 누른다.
      await tester.drag(find.text('09:00'), const Offset(-100, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제').last);
      await tester.pumpAndSettle();
      expect(find.text('09:00'), findsNothing);
      expect(find.text('08:00'), findsOneWidget);

      // 남은 한 개는 삭제할 수 없다.
      await tester.drag(find.text('08:00'), const Offset(-100, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      expect(find.text('복용 시간은 최소 1개 이상 입력해야 합니다.'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('첫 등록은 권한 흐름을 정확히 한 번 호출하고 이후 등록에서는 다시 호출하지 않는다', (tester) async {
      await openPage(tester, TargetPlatform.iOS);
      await tester.enterText(find.byType(CupertinoTextField), '혈압약');
      await tester.tap(find.text('월'));
      await tester.pump();
      await register(tester);

      expect(permissionCalls, 1);
      expect(popped, isA<MedicineAlarm>());
      expect(alarms.scheduled, hasLength(1));

      // 두 번째 신규 등록
      popped = null;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '비타민');
      await tester.tap(find.text('화'));
      await tester.pump();
      await register(tester);

      expect(permissionCalls, 1);
      expect(alarms.scheduled, hasLength(2));
    });

    testWidgets('권한 흐름은 설정 확인 다이얼로그 이후, 서버 호출 이전에 실행된다', (tester) async {
      final order = <String>[];
      await pumpPushedPage(
        tester,
        TargetPlatform.iOS,
        MedicineRegisterPage(
          scheduleService: schedule,
          alarmService: alarms,
          requestPermission: (context) async {
            order.add('permission:created=${schedule.created.length}');
            return true;
          },
        ),
      );
      await tester.enterText(find.byType(CupertinoTextField), '혈압약');
      await tester.tap(find.text('월'));
      await tester.pump();
      await register(tester);

      expect(order, ['permission:created=0']);
      expect(schedule.created, hasLength(1));
    });

    testWidgets('수정 화면에서는 권한 흐름을 호출하지 않는다', (tester) async {
      final initial = MedicineAlarm(
        id: '3',
        name: '기존약',
        times: const [TimeOfDay(hour: 9, minute: 30)],
        days: const ['월', '수'],
      );
      await openPage(tester, TargetPlatform.iOS, initial: initial);

      expect(find.text('약 수정'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      await register(tester, confirm: '저장');

      expect(permissionCalls, 0);
      expect(schedule.updatedBody, isNotNull);
      expect(schedule.created, isEmpty);
      expect(popped, isA<MedicineAlarm>());
    });

    testWidgets('권한이 거부돼도 등록은 저장되고 알람이 울리지 않는다는 토스트가 뜬다', (tester) async {
      permissionResult = false;
      await openPage(tester, TargetPlatform.iOS);
      await tester.enterText(find.byType(CupertinoTextField), '혈압약');
      await tester.tap(find.text('월'));
      await tester.pump();
      await register(tester);

      expect(permissionCalls, 1);
      expect(schedule.created, hasLength(1));
      expect(alarms.scheduled, hasLength(1));
      expect(popped, isA<MedicineAlarm>());
      expect(find.textContaining('알람이 울리지 않아요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 허용을 받지 못했으므로 다음 신규 등록에서 다시 묻는다.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '비타민');
      await tester.tap(find.text('화'));
      await tester.pump();
      await register(tester);
      expect(permissionCalls, 2);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('등록 화면이 보이는 동안 예산 경고를 AppToast로 보여준다', (tester) async {
      final warnings = StreamController<String>.broadcast();
      addTearDown(warnings.close);
      await pumpPushedPage(
        tester,
        TargetPlatform.iOS,
        MedicineRegisterPage(
          scheduleService: schedule,
          alarmService: alarms,
          budgetWarnings: warnings.stream,
        ),
      );

      warnings.add('알림은 64개까지만 예약돼요');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('알림은 64개까지만 예약돼요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('알람 등록 실패 시 안내 알럿을 보여주고 화면에 남는다', (tester) async {
      alarms.scheduleResult = false;
      await openPage(tester, TargetPlatform.iOS);
      await tester.enterText(find.byType(CupertinoTextField), '혈압약');
      await tester.tap(find.text('월'));
      await tester.pump();
      await register(tester);

      expect(find.text('알람 등록에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
      expect(popped, isNull);
    });
  });
}
