import 'package:flutter/material.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/calendar/data/completion_store.dart';
import 'package:after30/features/calendar/data/history_service.dart';

class MedicationService {
  // 로컬 더미 데이터
  static List<Medication> localDummyData() {
    final now = DateTime.now();
    return [
      Medication(
        id: '1',
        name: '혈압약',
        dosage: '1정',
        time: '아침',
        date: now.subtract(const Duration(days: 2)),
        status: '복용완료',
      ),
      Medication(
        id: '2',
        name: '당뇨약',
        dosage: '1정',
        time: '점심',
        date: now.subtract(const Duration(days: 1)),
        status: '복용완료',
      ),
      Medication(
        id: '3',
        name: '혈압약',
        dosage: '1정',
        time: '저녁',
        date: now,
        status: '복용예정',
      ),
      Medication(
        id: '4',
        name: '당뇨약',
        dosage: '1정',
        time: '아침',
        date: now,
        status: '복용완료',
      ),
    ];
  }

  // 추상화된 fetch 함수 - 현재는 로컬 데이터, 나중에 API로 교체 가능
  static Future<List<Medication>> fetchMedications(
    DateTime start,
    DateTime end,
  ) async {
    // 1) 서버 이력 연동 (GET /histories/)
    try {
      final api = HistoryService();
      final startStr = _formatYMD(start);
      final endStr = _formatYMD(end);
      final list = await api.getUserHistories(
        startDate: startStr,
        endDate: endStr,
      );

      final events = <Medication>[];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final id = (m['id'] ?? m['history_id'] ?? '').toString();
        final name = (m['medication_name'] ?? m['name'] ?? '약').toString();
        // 날짜/시간 추출
        String? dateStr = (m['scheduled_date'] ?? m['date'] ?? m['created_at'])
            ?.toString();
        String timeStr = (m['scheduled_time'] ?? m['time'] ?? '00:00')
            .toString();
        DateTime date;
        try {
          // ISO8601 혹은 yyyy-MM-dd 처리
          date = DateTime.parse(dateStr ?? _formatYMD(DateTime.now()));
        } catch (_) {
          final now = DateTime.now();
          date = DateTime(now.year, now.month, now.day);
        }
        // 상태 매핑: pending, taken, postponed, cancelled, missed
        String status = 'pending';
        if (m.containsKey('status')) {
          final raw = m['status'].toString().toLowerCase();
          const allowed = {
            'pending',
            'taken',
            'postponed',
            'cancelled',
            'missed',
          };
          status = allowed.contains(raw) ? raw : 'pending';
        } else if (m['taken'] == true || m['is_completed'] == true) {
          status = 'taken';
        } else if (m['missed'] == true) {
          status = 'missed';
        }

        events.add(
          Medication(
            id: id.isEmpty ? '${name}_${date.toIso8601String()}_$timeStr' : id,
            name: name,
            dosage: (m['dosage'] ?? '1정').toString(),
            time: timeStr,
            date: date,
            status: status,
            nfcEnabled: false,
          ),
        );
      }
      return events;
    } catch (_) {
      // 2) 실패 시 로컬 알람 기반으로 구성 (기존 로직)
      await Future.delayed(const Duration(milliseconds: 200));
      final alarms = await AlarmService().getAlarms();
      final completed = await CompletionStore.loadCompletedSet();
      final List<Medication> events = [];
      final rangeDays = end.difference(start).inDays.abs() + 1;
      for (int i = 0; i < rangeDays; i++) {
        final date = DateTime(
          start.year,
          start.month,
          start.day,
        ).add(Duration(days: i));
        final weekdayKor = _weekdayToKorStatic(date.weekday);
        for (final alarm in alarms) {
          if (!alarm.isActive) continue;
          if (!(alarm.everyDay || alarm.days.contains(weekdayKor))) continue;
          for (final t in alarm.times) {
            final timeKey =
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            final dateKey =
                '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
            final doseKey = '${alarm.id}_${dateKey}_${timeKey}';
            events.add(
              Medication(
                id: doseKey,
                name: alarm.name,
                dosage: '1정',
                time: timeKey,
                date: date,
                status: completed.contains(doseKey) ? 'taken' : 'pending',
                nfcEnabled: alarm.nfcEnabled,
              ),
            );
          }
        }
      }
      return events;
    }
  }

  static String _weekdayToKorStatic(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final idx = (weekday - 1).clamp(0, 6);
    return days[idx];
  }

  static String _formatYMD(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class MedicationProvider extends ChangeNotifier {
  List<Medication> _medications = [];
  bool _isLoading = false;
  String? _error;

  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 특정 날짜의 복용 기록 조회
  List<Medication> getMedicationsForDate(DateTime date) {
    return _medications.where((medication) {
      return medication.date.year == date.year &&
          medication.date.month == date.month &&
          medication.date.day == date.day;
    }).toList();
  }

  // 복용 기록 가져오기
  Future<void> fetchMedications(DateTime start, DateTime end) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final medications = await MedicationService.fetchMedications(start, end);
      _medications = medications;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 복용 상태 업데이트
  void updateMedicationStatus(String id, String status) {
    final index = _medications.indexWhere((med) => med.id == id);
    if (index != -1) {
      final medication = _medications[index];
      _medications[index] = Medication(
        id: medication.id,
        name: medication.name,
        dosage: medication.dosage,
        time: medication.time,
        date: medication.date,
        status: status,
        nfcEnabled: medication.nfcEnabled,
      );
      notifyListeners();
    }
  }

  // 캘린더에서 체크 시 완료 처리 및 영구 저장
  Future<void> markCompleted(String id) async {
    await CompletionStore.markCompleted(id);
    updateMedicationStatus(id, '복용완료');
  }

  Future<void> unmarkCompleted(String id) async {
    await CompletionStore.unmarkCompleted(id);
    updateMedicationStatus(id, '복용예정');
  }
}
