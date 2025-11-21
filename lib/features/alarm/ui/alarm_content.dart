import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/user_store.dart';

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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
      return Expanded(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SvgPicture.asset(
                  'assets/images/medi_icon.svg',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 50),
                const Text(
                  '등록된 약이 없어요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _goToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF235DFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 5,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '약 등록하기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.add, size: 18, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            ..._alarms.asMap().entries.map((entry) {
              final idx = entry.key;
              final alarm = entry.value;
              return Center(
                child: SizedBox(
                  width: 335,
                  height: 130,
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: alarm.isActive
                            ? const Color(0xFF235DFF)
                            : Colors.grey.shade400,
                      ),
                    ),
                    elevation: 0,
                    color: alarm.isActive
                        ? const Color(0xFFEBF0FF)
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 3, 8, 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top chips: days + times
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildChip(
                                alarm.everyDay ? '매일' : _formatDays(alarm.days),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...alarm.times.map(
                                        (t) => Padding(
                                          padding: const EdgeInsets.only(
                                            left: 6,
                                          ),
                                          child: _buildChip(_formatTimeHHmm(t)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                iconSize: 25,
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey[700],
                                ),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MedicineRegisterPage(
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

                          // Bottom: name + switch (align text with chip inner padding)
                          Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  alarm.isActive
                                      ? 'assets/images/alarmList_active.svg'
                                      : 'assets/images/alarmList_deactive.svg',
                                  width: 50,
                                  height: 50,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  alarm.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Transform.translate(
                                  offset: const Offset(0, 15),
                                  child: Transform.scale(
                                    scale: 0.85,
                                    child: Switch(
                                      value: alarm.isActive,
                                      onChanged: (value) => _toggleAlarm(idx),
                                      activeColor: Colors.white,
                                      activeTrackColor: const Color(0xFF235DFF),
                                      inactiveThumbColor: Colors.grey[400],
                                      inactiveTrackColor: Colors.grey[300],
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
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
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),
            Center(
              child: Material(
                borderRadius: BorderRadius.circular(4),
                color: Colors.transparent,
                child: ElevatedButton(
                  onPressed: _goToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF235DFF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
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

  String _formatTimeHHmm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  String _formatDays(List<String> days) {
    const order = ['월', '화', '수', '목', '금', '토', '일'];
    final set = days.toSet();
    final sorted = order.where(set.contains).toList();
    return sorted.join(' ');
  }
}
