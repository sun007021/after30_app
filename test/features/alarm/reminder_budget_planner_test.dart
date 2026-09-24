import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/features/alarm/data/reminder_budget_planner.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

MedicineAlarm _alarm({
  required String id,
  required String name,
  required List<TimeOfDay> times,
  required List<String> days,
  bool isActive = true,
}) {
  return MedicineAlarm(id: id, name: name, times: times, days: days, isActive: isActive);
}

void main() {
  group('ReminderBudgetPlanner.requestCost', () {
    test('7일 전체 선택은 시간당 1건(매일 반복 1건)으로 계산한다', () {
      final alarm = _alarm(
        id: 'a1',
        name: '혈압약',
        times: [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)],
        days: const ['월', '화', '수', '목', '금', '토', '일'],
      );
      expect(ReminderBudgetPlanner.requestCost(alarm), 2);
    });

    test('일부 요일만 선택하면 요일×시간 조합마다 1건이다(Android와 동일)', () {
      final alarm = _alarm(
        id: 'a2',
        name: '영양제',
        times: [const TimeOfDay(hour: 9, minute: 0)],
        days: const ['월', '수', '금'],
      );
      expect(ReminderBudgetPlanner.requestCost(alarm), 3);
    });

    test('비활성 알람은 0건이다', () {
      final alarm = _alarm(
        id: 'a3',
        name: '비활성',
        times: [const TimeOfDay(hour: 9, minute: 0)],
        days: const ['월'],
        isActive: false,
      );
      expect(ReminderBudgetPlanner.requestCost(alarm), 0);
    });

    test('시간/요일이 비어 있으면 0건이다', () {
      final alarm = _alarm(id: 'a4', name: '빈값', times: const [], days: const ['월']);
      expect(ReminderBudgetPlanner.requestCost(alarm), 0);
    });
  });

  group('ReminderBudgetPlanner.totalRequestCost / exceedsBudget', () {
    test('예시: 3개×하루 3회×7일(매일 반복 합침)은 9건으로 한도 이내다', () {
      final alarms = List.generate(
        3,
        (i) => _alarm(
          id: 'med$i',
          name: '약$i',
          times: const [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 13, minute: 0),
            TimeOfDay(hour: 20, minute: 0),
          ],
          days: const ['월', '화', '수', '목', '금', '토', '일'],
        ),
      );
      expect(ReminderBudgetPlanner.totalRequestCost(alarms), 9);
      expect(ReminderBudgetPlanner.exceedsBudget(alarms), isFalse);
    });

    test('요일별 개별 등록이 많으면 64개를 초과할 수 있다', () {
      // 10개 알람 × 하루 3회 × 3요일 = 90건 > 64
      final alarms = List.generate(
        10,
        (i) => _alarm(
          id: 'med$i',
          name: '약$i',
          times: const [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 13, minute: 0),
            TimeOfDay(hour: 20, minute: 0),
          ],
          days: const ['월', '수', '금'],
        ),
      );
      expect(ReminderBudgetPlanner.totalRequestCost(alarms), 90);
      expect(ReminderBudgetPlanner.exceedsBudget(alarms), isTrue);
    });
  });

  group('nextOccurrenceOf', () {
    test('오늘 그 시간이 지나지 않았으면 오늘을 반환한다', () {
      // 2026-09-23은 수요일이다.
      final now = DateTime(2026, 9, 23, 7, 0);
      final result = nextOccurrenceOf(now: now, dayKor: '수', hour: 8, minute: 0);
      expect(result, DateTime(2026, 9, 23, 8, 0));
    });

    test('오늘 그 시간이 이미 지났으면 다음 주로 넘어간다', () {
      final now = DateTime(2026, 9, 23, 9, 0); // 수요일 9시, 8시는 이미 지남
      final result = nextOccurrenceOf(now: now, dayKor: '수', hour: 8, minute: 0);
      expect(result, DateTime(2026, 9, 30, 8, 0));
    });

    test('다른 요일이면 그 주의 해당 요일로 이동한다', () {
      final now = DateTime(2026, 9, 23, 7, 0); // 수요일
      final result = nextOccurrenceOf(now: now, dayKor: '금', hour: 8, minute: 0);
      expect(result, DateTime(2026, 9, 25, 8, 0));
    });
  });

  group('buildBudgetedOccurrences', () {
    test('예산 이내면 전부(요일×시간 개수만큼) 담는다', () {
      final alarms = [
        _alarm(
          id: 'a1',
          name: '약A',
          times: [const TimeOfDay(hour: 8, minute: 0)],
          days: const ['월', '화'],
        ),
      ];
      final occurrences = buildBudgetedOccurrences(
        activeAlarms: alarms,
        now: DateTime(2026, 9, 23, 7, 0),
        limit: 64,
      );
      expect(occurrences.length, 2);
    });

    test('예산을 초과하면 가장 가까운 발생분부터 limit개만 남긴다', () {
      final alarms = List.generate(
        10,
        (i) => _alarm(
          id: 'med$i',
          name: '약$i',
          times: const [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 13, minute: 0),
            TimeOfDay(hour: 20, minute: 0),
          ],
          days: const ['월', '수', '금'],
        ),
      );
      final occurrences = buildBudgetedOccurrences(
        activeAlarms: alarms,
        now: DateTime(2026, 9, 23, 7, 0),
        limit: 64,
      );
      expect(occurrences.length, 64);
      // 오름차순(가장 가까운 발생부터) 정렬돼 있어야 한다.
      for (var i = 1; i < occurrences.length; i++) {
        expect(
          occurrences[i].nextFireAt.isAfter(occurrences[i - 1].nextFireAt) ||
              occurrences[i].nextFireAt.isAtSameMomentAs(occurrences[i - 1].nextFireAt),
          isTrue,
        );
      }
    });

    test('7일 전체 선택(매일) 알람은 실제로 울리는 만큼(7일 창 안에서 요일별 1건씩) 발생분을 담는다 (M2)', () {
      // 리뷰 M2: 예전에는 "대표 요일 하나"로만 계산해서, 매일 울리는
      // 알람인데도 발생분이 1건뿐이라 항상 예산에서 밀려났다.
      final alarms = [
        _alarm(
          id: 'daily',
          name: '매일약',
          times: [const TimeOfDay(hour: 8, minute: 0)],
          days: const ['월', '화', '수', '목', '금', '토', '일'],
        ),
      ];
      // 2026-09-23은 수요일이다.
      final occurrences = buildBudgetedOccurrences(
        activeAlarms: alarms,
        now: DateTime(2026, 9, 23, 7, 0),
      );
      // 7일 창 안에서 요일 7개 모두 정확히 1번씩 발생한다.
      expect(occurrences.length, 7);
      final fireDates = occurrences.map((o) => o.nextFireAt).toSet();
      expect(fireDates.length, 7);
    });
  });
}
