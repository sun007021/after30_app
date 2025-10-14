import 'package:flutter/material.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';

class MedicationService {
  static String _normalizeTime(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(s);
    if (m != null) {
      final hh = (m.group(1) ?? '0').padLeft(2, '0');
      final mm = m.group(2) ?? '00';
      final ss = m.group(3) ?? '00';
      return '$hh:$mm:$ss';
    }
    if (RegExp(r'^\d{3,4}$').hasMatch(s)) {
      final p = s.padLeft(4, '0');
      return '${p.substring(0, 2)}:${p.substring(2, 4)}:00';
    }
    return s;
  }

  static String _normalizeDateStr(String s) {
    try {
      final d = DateTime.parse(s);
      return _formatYMD(d);
    } catch (_) {
      // 예상치 못한 포맷 대응 (예: yyyy/M/d, yyyy.MM.dd 등)
      final onlyDate = s.split('T').first.split(' ').first;
      final rep = onlyDate.replaceAll('.', '-').replaceAll('/', '-');
      final parts = rep.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return _formatYMD(DateTime(y, m, d));
        }
      }
      return s; // 마지막 수단: 원문 반환
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

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
        status: 'taken',
      ),
      Medication(
        id: '2',
        name: '당뇨약',
        dosage: '1정',
        time: '점심',
        date: now.subtract(const Duration(days: 1)),
        status: 'taken',
      ),
      Medication(
        id: '3',
        name: '혈압약',
        dosage: '1정',
        time: '저녁',
        date: now,
        status: 'pending',
      ),
      Medication(
        id: '4',
        name: '당뇨약',
        dosage: '1정',
        time: '아침',
        date: now,
        status: 'taken',
      ),
    ];
  }

  // 하이브리드: 스케줄로 슬롯 생성 후, 서버 히스토리로 상태 덮어쓰기
  static Future<List<Medication>> fetchMedications(
    DateTime start,
    DateTime end,
  ) async {
    // 1) 스케줄 조회(이름/부가정보 포함)
    final scheduleService = ScheduleService();
    final schedules = await scheduleService.getSchedules(includeInactive: true);
    final scheduleNameMap = <int, String>{};
    for (final s in schedules) {
      final m = s as Map<String, dynamic>;
      final scheduleId = (m['id'] as num).toInt();
      scheduleNameMap[scheduleId] = (m['medication_name'] as String?) ?? '';
    }

    // 2) 구간 날짜 목록 생성
    final totalDays = end.difference(start).inDays.abs() + 1;
    final daysInRange = List.generate(
      totalDays,
      (i) =>
          DateTime(start.year, start.month, start.day).add(Duration(days: i)),
    );

    // 요일 enum 맵
    const weekdayEnum = {
      1: 'MON',
      2: 'TUE',
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };

    // 3) 스케줄 → 날짜별 슬롯 생성(기본 pending)
    final meds = <Medication>[];
    for (final s in schedules) {
      final m = s as Map<String, dynamic>;
      final scheduleId = (m['id'] as num).toInt();
      final medName = (m['medication_name'] as String?) ?? '';
      final times = ((m['times'] as List?) ?? [])
          .map((t) => _normalizeTime(t.toString()).substring(0, 5))
          .toList();
      final repeatDays = ((m['repeat_days'] as List?) ?? [])
          .map((d) => d.toString())
          .toList();
      final isActive = (m['is_active'] as bool?) ?? true;
      final everyDay = repeatDays.length == 7 || repeatDays.isEmpty;
      if (!isActive) continue;

      for (final d in daysInRange) {
        final enumDay = weekdayEnum[d.weekday] ?? 'MON';
        if (!everyDay && !repeatDays.contains(enumDay)) continue;
        for (final t in times) {
          meds.add(
            Medication(
              id: '${scheduleId}_${_formatYMD(d)}_$t',
              name: medName,
              dosage: '1정',
              time: t,
              date: d,
              status: 'pending',
              nfcEnabled: false,
              scheduleId: scheduleId,
            ),
          );
        }
      }
    }

    // 4) 히스토리 조회하여 상태 덮어쓰기 + 없던 히스토리는 추가
    final hist = HistoryService();
    final list = await hist.getUserHistories(
      startDate: _formatYMD(start),
      endDate: _formatYMD(end),
    );

    final historyMap = <String, Map<String, dynamic>>{};
    final historyByNameMap = <String, Map<String, dynamic>>{};
    final historyByDateTime = <String, List<Map<String, dynamic>>>{};
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final h = item;
      final sid =
          _parseInt(h['schedule_id']) ??
          _parseInt(h['scheduleId']) ??
          _parseInt((h['schedule'] is Map) ? (h['schedule']['id']) : null);
      final dateStr = (h['scheduled_date'] ?? h['scheduledDate'] ?? h['date'])
          ?.toString();
      final timeStr = (h['scheduled_time'] ?? h['scheduledTime'] ?? h['time'])
          ?.toString();
      final medNameFallback =
          (h['medication_name'] ?? h['medicationName'])?.toString() ?? '';
      if (sid == null || dateStr == null || timeStr == null) continue;
      final tNorm = _normalizeTime(timeStr);
      final dNorm = _normalizeDateStr(dateStr);
      final hhmm = tNorm.substring(0, 5);
      historyMap['${sid}_${dNorm}_$hhmm'] = h;
      historyMap['${sid}_${dNorm}_$tNorm'] = h; // 양 포맷 허용
      if (medNameFallback.isNotEmpty) {
        historyByNameMap['${medNameFallback}_${dNorm}_$hhmm'] = h;
        historyByNameMap['${medNameFallback}_${dNorm}_$tNorm'] = h;
      }
      final dtKey = '${dNorm}_$hhmm';
      final listAt = historyByDateTime.putIfAbsent(
        dtKey,
        () => <Map<String, dynamic>>[],
      );
      listAt.add(h);
    }

    // 덮어쓰기
    final usedHistoryKeys = <String>{};
    for (var i = 0; i < meds.length; i++) {
      final base = '${meds[i].scheduleId}_${_formatYMD(meds[i].date)}_';
      final key1 = base + meds[i].time; // HH:mm
      final key2 = base + '${meds[i].time}:00'; // HH:mm:ss
      Map<String, dynamic>? h = historyMap[key1] ?? historyMap[key2];
      if (h == null) {
        // 이름 기반 느슨한 매칭 시도
        final nameBase = '${meds[i].name}_${_formatYMD(meds[i].date)}_';
        final nKey1 = nameBase + meds[i].time;
        final nKey2 = nameBase + '${meds[i].time}:00';
        h = historyByNameMap[nKey1] ?? historyByNameMap[nKey2];
        if (h == null) {
          // 날짜+시간(단일 후보) 기반 폴백
          final dtKey = '${_formatYMD(meds[i].date)}_${meds[i].time}';
          final candidates =
              historyByDateTime[dtKey] ?? const <Map<String, dynamic>>[];
          if (candidates.length == 1) {
            h = candidates.first;
          } else if (candidates.length > 1) {
            // 같은 시간대에 여러 히스토리가 있으면 이름으로 한 번 더 필터링
            final byName = candidates.where((c) {
              final nm =
                  (c['medication_name'] ?? c['medicationName'])?.toString() ??
                  '';
              return nm.isNotEmpty && nm == meds[i].name;
            }).toList();
            if (byName.length == 1) {
              h = byName.first;
            }
          }
          if (h == null) {
            continue;
          }
        }
      }
      // 사용된 히스토리 키 기록
      final usedKey = historyMap[key1] != null
          ? key1
          : (historyMap[key2] != null
                ? key2
                : (() {
                    // 폴백으로 선택된 경우: sid/date/time으로 재구성
                    final hist = h!;
                    final sidFromH =
                        _parseInt(hist['schedule_id']) ??
                        _parseInt(hist['scheduleId']) ??
                        _parseInt(
                          (hist['schedule'] is Map)
                              ? (hist['schedule']['id'])
                              : null,
                        );
                    final dFromH = _normalizeDateStr(
                      (hist['scheduled_date'] ??
                              hist['scheduledDate'] ??
                              hist['date'])
                          .toString(),
                    );
                    final tFromH = _normalizeTime(
                      (hist['scheduled_time'] ??
                              hist['scheduledTime'] ??
                              hist['time'])
                          .toString(),
                    ).substring(0, 5);
                    return '${sidFromH}_${dFromH}_$tFromH';
                  })());
      usedHistoryKeys.add(usedKey);

      String status =
          ((h['status'] ?? h['action'] ?? h['state'])?.toString() ?? '')
              .toLowerCase();
      if (status.isEmpty) {
        if (h['taken'] == true ||
            h['is_completed'] == true ||
            h['taken_at'] != null) {
          status = 'taken';
        } else if (h['cancelled'] == true) {
          status = 'cancelled';
        } else if (h['missed'] == true) {
          status = 'missed';
        } else if (h['postponed'] == true || h['postponed_to'] != null) {
          status = 'postponed';
        } else {
          status = 'pending';
        }
      }

      meds[i] = meds[i].copyWith(
        status: status,
        historyId: (h['id'] as num?)?.toInt(),
        takenAt: h['taken_at'] != null
            ? DateTime.tryParse(h['taken_at'].toString())
            : null,
      );
    }

    // 스케줄에 없던 히스토리(예: 단발 일정) 추가
    for (final entry in historyMap.entries) {
      if (usedHistoryKeys.contains(entry.key)) continue;
      final h = entry.value;
      final sid =
          _parseInt(h['schedule_id']) ??
          _parseInt(h['scheduleId']) ??
          _parseInt((h['schedule'] is Map) ? (h['schedule']['id']) : null);
      final dateStr = (h['scheduled_date'] ?? h['scheduledDate'] ?? h['date'])
          ?.toString();
      final timeStr = (h['scheduled_time'] ?? h['scheduledTime'] ?? h['time'])
          ?.toString();
      if (sid == null || dateStr == null || timeStr == null) continue;
      DateTime day;
      try {
        day = DateTime.parse(dateStr);
      } catch (_) {
        final p = dateStr.split('-');
        day = DateTime(
          int.tryParse(p.elementAt(0)) ?? start.year,
          int.tryParse(p.elementAt(1)) ?? start.month,
          int.tryParse(p.elementAt(2)) ?? start.day,
        );
      }
      final timeLabel = _normalizeTime(timeStr).substring(0, 5);
      String status =
          ((h['status'] ?? h['action'] ?? h['state'])?.toString() ?? '')
              .toLowerCase();
      if (status.isEmpty) {
        if (h['taken'] == true ||
            h['is_completed'] == true ||
            h['taken_at'] != null) {
          status = 'taken';
        } else if (h['cancelled'] == true) {
          status = 'cancelled';
        } else if (h['missed'] == true) {
          status = 'missed';
        } else if (h['postponed'] == true || h['postponed_to'] != null) {
          status = 'postponed';
        } else {
          status = 'pending';
        }
      }
      meds.add(
        Medication(
          id: '${sid}_${_formatYMD(day)}_$timeLabel',
          name: scheduleNameMap[sid] ?? '',
          dosage: '1정',
          time: timeLabel,
          date: day,
          status: status,
          nfcEnabled: false,
          scheduleId: sid,
          historyId: (h['id'] as num?)?.toInt(),
          takenAt: h['taken_at'] != null
              ? DateTime.tryParse(h['taken_at'].toString())
              : null,
        ),
      );
    }

    meds.sort((a, b) => a.time.compareTo(b.time));
    return meds;
  }

  // no-op placeholder removed

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
        scheduleId: medication.scheduleId,
      );
      notifyListeners();
    }
  }

  // 서버 상태 변경 연동
  Future<void> markCompleted(String id) async {
    final med = _medications.firstWhere(
      (m) => m.id == id,
      orElse: () => Medication(
        id: id,
        name: '',
        dosage: '',
        time: '00:00',
        date: DateTime.now(),
        status: 'pending',
      ),
    );
    // 이미 taken이면 POST/process가 아니라 PUT/update로 처리되도록 토글 동작 수행
    if (med.status.toLowerCase() == 'taken') {
      await unmarkCompleted(id);
      return;
    }
    final hs = HistoryService();
    if (med.historyId != null) {
      await hs.updateHistory(med.historyId!, {
        'status': 'taken',
        'taken_at': DateTime.now().toIso8601String(),
      });
    } else if (med.scheduleId != null) {
      await hs.markTaken(
        scheduleId: med.scheduleId!,
        scheduledDate: MedicationService._formatYMD(med.date),
        scheduledTime: med.time.substring(0, 5),
      );
    }
    updateMedicationStatus(id, 'taken');
    // 서버 기준으로 재조회하여 UI 일관성 보장
    await fetchMedications(
      med.date.subtract(const Duration(days: 30)),
      med.date.add(const Duration(days: 30)),
    );
  }

  Future<void> unmarkCompleted(String id) async {
    final med = _medications.firstWhere(
      (m) => m.id == id,
      orElse: () => Medication(
        id: id,
        name: '',
        dosage: '',
        time: '00:00',
        date: DateTime.now(),
        status: 'pending',
      ),
    );
    final hs = HistoryService();
    if (med.historyId != null) {
      // taken을 다시 누르면 서버 상태를 cancelled로 변경
      await hs.updateHistory(med.historyId!, {'status': 'cancelled'});
    } else if (med.scheduleId != null) {
      // 기존 히스토리 없던 경우에는 서버에 새로운 기록을 만들지 않고 재조회만 수행
      // (서버 정책상 취소/되돌리기는 기존 히스토리가 있을 때만 의미)
    }
    updateMedicationStatus(id, 'cancelled');
    await fetchMedications(
      med.date.subtract(const Duration(days: 30)),
      med.date.add(const Duration(days: 30)),
    );
  }
}
