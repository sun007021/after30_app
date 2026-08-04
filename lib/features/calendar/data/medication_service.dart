import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/user_store.dart';

class MedicationService {
  static String _formatYMD(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

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

  static Future<List<Medication>> fetchMedications(
    DateTime start,
    DateTime end, {
    int? userId,
  }) async {
    final currentUserIdStr = await UserStore.getCurrentUserId();
    final currentUserId = int.tryParse(currentUserIdStr ?? '');
    final isOtherUser =
        userId != null && currentUserId != null && userId != currentUserId;
    final scheduleUserId = isOtherUser ? userId : null;

    final scheduleService = ScheduleService();
    final schedules = await scheduleService.getSchedules(
      includeInactive: true,
      userId: scheduleUserId,
    );
    final prefs = await SharedPreferences.getInstance();
    final localPrefsUserId = currentUserIdStr;

    // /schedules/의 created_at 기준일(가장 이른 생성일)을 계산
    DateTime? earliestCreatedAtDateOnly;
    try {
      for (final s in schedules) {
        if (s is! Map<String, dynamic>) continue;
        final createdAtStr = s['created_at']?.toString();
        if (createdAtStr == null || createdAtStr.trim().isEmpty) continue;
        final parsed = DateTime.tryParse(createdAtStr);
        if (parsed == null) continue;
        final local = parsed.toLocal();
        final only = DateTime(local.year, local.month, local.day);
        if (earliestCreatedAtDateOnly == null ||
            only.isBefore(earliestCreatedAtDateOnly)) {
          earliestCreatedAtDateOnly = only;
        }
      }
    } catch (_) {
      // created_at 파싱 실패 시 필터 미적용
      earliestCreatedAtDateOnly = null;
    }

    final totalDays = end.difference(start).inDays.abs() + 1;
    final daysInRange = List.generate(
      totalDays,
      (i) =>
          DateTime(start.year, start.month, start.day).add(Duration(days: i)),
    );

    const weekdayEnum = {
      1: 'MON',
      2: 'TUE',
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };

    final meds = <Medication>[];
    final scheduleIdToName = <int, String>{};
    for (final s in schedules) {
      if (s is! Map<String, dynamic>) continue;
      final scheduleId = (s['id'] as num).toInt();
      final medName = (s['medication_name'] as String?) ?? '';
      scheduleIdToName[scheduleId] = medName;
      final times = ((s['times'] as List?) ?? [])
          .map((t) => _normalizeTime(t.toString()).substring(0, 5))
          .toList();
      final repeatDays = ((s['repeat_days'] as List?) ?? [])
          .map((d) => d.toString())
          .toList();
      final isActive = (s['is_active'] as bool?) ?? true;
      final everyDay = repeatDays.isEmpty || repeatDays.length == 7;

      // 스케줄 시작일(start_date) 이전에는 약 항목을 생성하지 않도록 필터링
      DateTime? startDate;
      final startDateStr = (s['start_date'] as String?);
      if (startDateStr != null && startDateStr.trim().isNotEmpty) {
        // 기대 포맷: YYYY-MM-DD
        try {
          final parts = startDateStr.split('-');
          if (parts.length >= 3) {
            final y = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 1;
            final d = int.tryParse(parts[2]) ?? 1;
            startDate = DateTime(y, m, d);
          }
        } catch (_) {
          startDate = null;
        }
      }

      for (final d in daysInRange) {
        // created_at 이전 날짜는 달력 게이지(=약 항목) 생성 안 함
        if (earliestCreatedAtDateOnly != null) {
          final onlyDay = DateTime(d.year, d.month, d.day);
          if (onlyDay.isBefore(earliestCreatedAtDateOnly)) continue;
        }
        // 시작일이 지정된 경우, 시작일 이전 날짜는 스킵
        if (startDate != null) {
          final onlyDay = DateTime(d.year, d.month, d.day);
          if (onlyDay.isBefore(startDate)) continue;
        }
        // 비활성 스케줄일 경우, '비활성화한 날짜' 이전 날짜만 생성
        if (!isActive) {
          DateTime? cutoff;
          // 서버 제공 비활성화 일자 추정
          final serverCutoffStr =
              (s['deactivated_at'] ??
                      s['deactivated_date'] ??
                      s['inactive_since'] ??
                      s['ended_at'] ??
                      s['end_date'] ??
                      s['stop_date'])
                  ?.toString();
          if (serverCutoffStr != null && serverCutoffStr.trim().isNotEmpty) {
            DateTime? parsed = DateTime.tryParse(serverCutoffStr);
            if (parsed == null) {
              try {
                final p = serverCutoffStr.split('-');
                if (p.length >= 3) {
                  parsed = DateTime(
                    int.tryParse(p[0]) ?? 0,
                    int.tryParse(p[1]) ?? 1,
                    int.tryParse(p[2]) ?? 1,
                  );
                }
              } catch (_) {}
            }
            if (parsed != null) {
              cutoff = DateTime(parsed.year, parsed.month, parsed.day);
            }
          }
          // 로컬 저장 기준일(토글 시점) 사용 - 본인 스케줄에만 적용
          if (cutoff == null && !isOtherUser) {
            final keyNs = localPrefsUserId != null
                ? 'inactive_since_${localPrefsUserId}_${scheduleId.toString()}'
                : 'inactive_since_${scheduleId.toString()}';
            final localStr =
                prefs.getString(keyNs) ??
                prefs.getString('inactive_since_${scheduleId.toString()}');
            if (localStr != null && localStr.trim().isNotEmpty) {
              final p = localStr.split('-');
              if (p.length >= 3) {
                cutoff = DateTime(
                  int.tryParse(p[0]) ?? 0,
                  int.tryParse(p[1]) ?? 1,
                  int.tryParse(p[2]) ?? 1,
                );
              }
            }
          }
          // 최후 수단: 오늘 날짜
          cutoff ??= () {
            final t = DateTime.now();
            return DateTime(t.year, t.month, t.day);
          }();
          final onlyDay = DateTime(d.year, d.month, d.day);
          if (!onlyDay.isBefore(cutoff)) continue;
        }
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

    // Merge with histories
    final hist = HistoryService();
    final histList = await hist.getUserHistories(
      startDate: _formatYMD(start),
      endDate: _formatYMD(end),
      userId: scheduleUserId,
    );

    final historyMap = <String, Map<String, dynamic>>{};
    for (final item in histList) {
      if (item is! Map<String, dynamic>) continue;
      final sid = (item['schedule_id'] as num?)?.toInt();
      final dateStr = item['scheduled_date']?.toString();
      final timeStr = item['scheduled_time']?.toString();
      if (sid == null || dateStr == null || timeStr == null) continue;
      final dNorm = dateStr; // already YYYY-MM-DD
      final tNorm = _normalizeTime(timeStr).substring(0, 5);
      historyMap['${sid}_${dNorm}_$tNorm'] = item;
    }

    for (var i = 0; i < meds.length; i++) {
      final key =
          '${meds[i].scheduleId}_${_formatYMD(meds[i].date)}_${meds[i].time}';
      final h = historyMap[key];
      if (h == null) continue;
      String status = (h['status']?.toString() ?? '').toLowerCase();
      if (status.isEmpty) status = 'pending';
      meds[i] = meds[i].copyWith(
        status: status,
        historyId: (h['id'] as num?)?.toInt(),
        takenAt: h['taken_at'] != null
            ? DateTime.tryParse(h['taken_at'].toString())
            : null,
      );
    }

    // 비활성 스케줄이라 기본 생성이 없더라도, 해당 기간 히스토리가 있으면 표시용 항목 보강
    final existingKeys = meds
        .map((m) => '${m.scheduleId}_${_formatYMD(m.date)}_${m.time}')
        .toSet();
    for (final h in histList) {
      if (h is! Map<String, dynamic>) continue;
      final sid = (h['schedule_id'] as num?)?.toInt();
      final dateStr = h['scheduled_date']?.toString();
      final timeStr = h['scheduled_time']?.toString();
      if (sid == null || dateStr == null || timeStr == null) continue;
      final tNorm = _normalizeTime(timeStr).substring(0, 5);
      final key = '${sid}_${dateStr}_$tNorm';
      if (existingKeys.contains(key)) continue;
      DateTime? date;
      try {
        date = DateTime.tryParse(dateStr);
      } catch (_) {
        date = null;
      }
      if (date == null) continue;
      String status = (h['status']?.toString() ?? '').toLowerCase();
      if (status.isEmpty) status = 'pending';
      meds.add(
        Medication(
          id: key,
          name: scheduleIdToName[sid] ?? '',
          dosage: '1정',
          time: tNorm,
          date: date,
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
    // 히스토리 보강 이후에도 created_at 이전 날짜 항목은 제거
    if (earliestCreatedAtDateOnly != null) {
      meds.removeWhere((m) {
        final only = DateTime(m.date.year, m.date.month, m.date.day);
        return only.isBefore(earliestCreatedAtDateOnly!);
      });
    }
    return meds;
  }

  static Future<List<Medication>> fetchFamilyMemberMedications(
    int memberUserId,
    DateTime start,
    DateTime end,
  ) async {
    final hist = HistoryService();
    final histList = await hist.getFamilyMemberHistories(
      memberUserId: memberUserId,
      startDate: _formatYMD(start),
      endDate: _formatYMD(end),
    );

    final meds = <Medication>[];
    for (final item in histList) {
      if (item is! Map<String, dynamic>) continue;
      final sid = (item['schedule_id'] as num?)?.toInt();
      final dateStr = item['scheduled_date']?.toString();
      final timeStr = item['scheduled_time']?.toString();
      if (dateStr == null || timeStr == null) continue;

      final tNorm = _normalizeTime(timeStr).substring(0, 5);
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      var status = (item['status']?.toString() ?? '').toLowerCase();
      if (status.isEmpty) status = 'pending';

      meds.add(
        Medication(
          id: '${sid ?? 0}_${dateStr}_$tNorm',
          name: item['medication_name']?.toString() ?? '',
          dosage: '1정',
          time: tNorm,
          date: date,
          status: status,
          scheduleId: sid,
          historyId: (item['id'] as num?)?.toInt(),
          takenAt: item['taken_at'] != null
              ? DateTime.tryParse(item['taken_at'].toString())
              : null,
        ),
      );
    }

    meds.sort((a, b) => a.time.compareTo(b.time));
    return meds;
  }
}
