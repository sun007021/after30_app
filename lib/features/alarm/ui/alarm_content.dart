import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알람 삭제'),
        content: Text('${alarm.name} 알람을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
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
      } else {
        if (scheduleId != null) {
          await _scheduleService.activateSchedule(scheduleId);
        }
        await _alarmService.scheduleAlarm(alarm);
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
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 80, color: Colors.black),
            const SizedBox(height: 24),
            const Text(
              '등록된 약이 없어요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '약을 등록한 후 알람을 받아보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA7B0),
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('약 등록하기'),
            ),
          ],
        ),
      );
    }
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24, top: 8),
                  child: Text(
                    'NFC 관리하기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            ..._alarms.asMap().entries.map((entry) {
              final idx = entry.key;
              final alarm = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.grey),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            alarm.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.circle,
                            color: alarm.isActive ? Colors.green : Colors.grey,
                            size: 10,
                          ),
                          const Spacer(),
                          Switch(
                            value: alarm.isActive,
                            onChanged: (value) => _toggleAlarm(idx),
                            activeColor: Colors.pink,
                            inactiveThumbColor: Colors.grey[400],
                            inactiveTrackColor: Colors.grey[300],
                          ),
                          PopupMenuButton<String>(
                            color: Colors.white,
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[700],
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MedicineRegisterPage(
                                      initialAlarm: alarm,
                                    ),
                                  ),
                                );
                                if (result is MedicineAlarm) {
                                  await _loadAlarms();
                                }
                              } else if (value == 'delete') {
                                await _deleteAlarm(idx);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('알람 수정'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('알람 삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 4),
                          ...alarm.times.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(_formatTimeOfDay(t)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.everyDay ? '매일' : alarm.days.join(', '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      if (alarm.nfcEnabled) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.nfc, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'NFC 연동됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 50),
            Center(
              child: Material(
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
                child: ElevatedButton(
                  onPressed: _goToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA7B0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text('약 등록하기  +'),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? '오전' : '오후';
    return '$period $hour:$minute';
  }
}
