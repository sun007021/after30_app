import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/calendar/models/medication.dart';

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
    DateTime end,
  ) async {
    final scheduleService = ScheduleService();
    final schedules = await scheduleService.getSchedules(includeInactive: true);

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
    for (final s in schedules) {
      if (s is! Map<String, dynamic>) continue;
      final scheduleId = (s['id'] as num).toInt();
      final medName = (s['medication_name'] as String?) ?? '';
      final times = ((s['times'] as List?) ?? [])
          .map((t) => _normalizeTime(t.toString()).substring(0, 5))
          .toList();
      final repeatDays = ((s['repeat_days'] as List?) ?? [])
          .map((d) => d.toString())
          .toList();
      final isActive = (s['is_active'] as bool?) ?? true;
      if (!isActive) continue;
      final everyDay = repeatDays.isEmpty || repeatDays.length == 7;

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

    // Merge with histories
    final hist = HistoryService();
    final histList = await hist.getUserHistories(
      startDate: _formatYMD(start),
      endDate: _formatYMD(end),
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

    meds.sort((a, b) => a.time.compareTo(b.time));
    return meds;
  }
}
