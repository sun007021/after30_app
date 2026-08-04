import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/ui/widgets/alarm_card.dart';
import 'package:after30/features/alarm/ui/widgets/empty_alarm_section.dart';
import 'package:after30/utils/responsive.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';

class AlarmContent extends StatefulWidget {
  const AlarmContent({super.key});

  @override
  State<AlarmContent> createState() => _AlarmContentState();
}

class _AlarmContentState extends State<AlarmContent> {
  final List<MedicineAlarm> _alarms = [];
  final AlarmService _alarmService = AlarmService();
  final ScheduleService _scheduleService = ScheduleService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final schedules = await _scheduleService.getSchedules(
        includeInactive: true,
      );
      final mapped = schedules.map<MedicineAlarm>((s) {
        final m = s as Map<String, dynamic>;
        final id = (m['id'] as num).toInt().toString();
        final name = (m['medication_name'] as String?) ?? '';
        final times = ((m['times'] as List?) ?? [])
            .map((t) => t.toString())
            .map((t) {
              final parts = t.split(':');
              final h = int.tryParse(parts[0]) ?? 8;
              final min = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
              return TimeOfDay(hour: h, minute: min);
            })
            .toList();
        final repeatDays = ((m['repeat_days'] as List?) ?? [])
            .map((d) => d.toString())
            .toList();
        const korMap = {
          'MON': '월',
          'TUE': '화',
          'WED': '수',
          'THU': '목',
          'FRI': '금',
          'SAT': '토',
          'SUN': '일',
        };
        final days = repeatDays.map((e) => korMap[e] ?? '월').toList();
        final everyDay = days.length == 7;
        final isActive = (m['is_active'] as bool?) ?? true;
        return MedicineAlarm(
          id: id,
          name: name,
          times: times,
          days: days,
          everyDay: everyDay,
          isActive: isActive,
          nfcEnabled: false,
        );
      }).toList();

      setState(() {
        _alarms
          ..clear()
          ..addAll(mapped);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('알람 불러오기 실패: $e');
    }
  }

  Future<void> _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineRegisterPage()),
    );
    if (result is MedicineAlarm) {
      await _loadAlarms();
    }
  }

  Future<void> _deleteAlarm(int index) async {
    final alarm = _alarms[index];

    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: '약 정보를 삭제하시겠습니까?',
      message: '삭제하면, 그동안 쌓인 복약 기록과 설정된 알림이 모두 사라져요.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );

    if (confirmed == true) {
      try {
        final scheduleId = int.tryParse(alarm.id);
        if (scheduleId != null) {
          await _scheduleService.deleteSchedule(scheduleId);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('서버 삭제 실패: $e')));
        }
        return;
      }

      try {
        await _alarmService.cancelAlarm(alarm.id);
      } catch (_) {}
      await _loadAlarms();
    }
  }

  Future<void> _toggleAlarm(int index) async {
    final alarm = _alarms[index];
    final newState = !alarm.isActive;

    if (!newState) {
      final confirmed = await DoubleCheckDialog.show(
        context: context,
        title: '복용을 중단하시겠습니까?',
        message: '증상이 완화되어 복용을 멈추시는 건가요? 기록은 남기고 알림만 끌 수 있습니다.',
        cancelLabel: '아니요',
        confirmLabel: '중단하기',
      );
      if (!confirmed) return;
    }

    setState(() {
      _alarms[index] = alarm.copyWith(isActive: newState);
    });

    try {
      final scheduleId = int.tryParse(alarm.id);
      if (!newState) {
        if (scheduleId != null) {
          await _scheduleService.deactivateSchedule(scheduleId);
        }
        await _alarmService.cancelAlarm(alarm.id);
        // 비활성화 날짜를 로컬에 기록 (달력 표시 컷오프 기준)
        try {
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now();
          final dateStr =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final userId = await UserStore.getCurrentUserId();
          final keyNs = userId != null
              ? 'inactive_since_${userId}_${alarm.id}'
              : 'inactive_since_${alarm.id}';
          await prefs.setString(keyNs, dateStr);
        } catch (_) {}
      } else {
        if (scheduleId != null) {
          await _scheduleService.activateSchedule(scheduleId);
        }
        await _alarmService.scheduleAlarm(alarm);
        // 재활성화 시 비활성 기준일 제거
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = await UserStore.getCurrentUserId();
          final keyNs = userId != null
              ? 'inactive_since_${userId}_${alarm.id}'
              : 'inactive_since_${alarm.id}';
          await prefs.remove(keyNs);
          // 레거시 키도 함께 정리
          await prefs.remove('inactive_since_${alarm.id}');
        } catch (_) {}
      }

      await _loadAlarms();
    } catch (e) {
      setState(() {
        _alarms[index] = alarm.copyWith(isActive: !newState);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상태 변경 동기화 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_alarms.isEmpty) {
      return EmptyAlarmSection(onAdd: _goToRegister);
    }

    return Expanded(
      child: SingleChildScrollView(
        padding: Responsive.responsivePadding(context, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: Responsive.responsiveHeight(context, 12)),
            ..._alarms.asMap().entries.map((entry) {
              final idx = entry.key;
              final alarm = entry.value;
              return AlarmCard(
                alarm: alarm,
                onToggle: () => _toggleAlarm(idx),
                onEdit: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MedicineRegisterPage(initialAlarm: alarm),
                    ),
                  );
                  if (result is MedicineAlarm) {
                    await _loadAlarms();
                  }
                },
                onDelete: () => _deleteAlarm(idx),
              );
            }),
            SizedBox(height: Responsive.responsiveHeight(context, 40)),
            Center(
              child: Material(
                borderRadius: BorderRadius.circular(
                  Responsive.responsiveValue(context, 4),
                ),
                color: Colors.transparent,
                child: ElevatedButton(
                  onPressed: _goToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF235DFF),
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      Responsive.responsiveValue(context, 180),
                      Responsive.responsiveValue(context, 32),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        Responsive.responsiveValue(context, 4),
                      ),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    '약 등록하기  +',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 14),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 30)),
          ],
        ),
      ),
    );
  }
}
