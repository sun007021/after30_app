import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/top_curve_clipper.dart';
import 'package:after30/features/alarm/ui/widgets/alarm_header.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';

class MedicineRegisterPage extends StatefulWidget {
  final MedicineAlarm? initialAlarm;
  const MedicineRegisterPage({super.key, this.initialAlarm});

  @override
  State<MedicineRegisterPage> createState() => _MedicineRegisterPageState();
}

class _MedicineRegisterPageState extends State<MedicineRegisterPage> {
  late final TextEditingController _medicineController;
  late List<String> _selectedDays;
  final List<String> _allDays = ['월', '화', '수', '목', '금', '토', '일'];
  late List<TimeOfDay> _times;
  late bool _allDaysSelected;
  bool _nfcEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.initialAlarm;
    _medicineController = TextEditingController(text: alarm?.name ?? '');
    _selectedDays = alarm?.days ?? ['월', '화', '수', '목', '금', '토', '일'];
    _times = alarm != null
        ? List<TimeOfDay>.from(alarm.times)
        : [TimeOfDay(hour: 8, minute: 0)];
    _allDaysSelected = _selectedDays.length == 7;
    if (alarm != null) {
      _nfcEnabled = alarm.nfcEnabled;
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    super.dispose();
  }

  bool get _isMedicineEmpty => _medicineController.text.trim().isEmpty;

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _allDaysSelected = _selectedDays.length == 7;
    });
  }

  void _toggleAllDays() {
    setState(() {
      if (_allDaysSelected) {
        _selectedDays.clear();
        _allDaysSelected = false;
      } else {
        _selectedDays.clear();
        _selectedDays.addAll(_allDays);
        _allDaysSelected = true;
      }
    });
  }

  void _addTime() {
    setState(() {
      _times.add(TimeOfDay(hour: 8, minute: 0));
    });
  }

  void _removeTime() {
    setState(() {
      if (_times.length == 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('안내'),
            content: const Text('복용 시간은 최소 1개 이상 입력해야 합니다.'),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        _times.removeLast();
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? '오전' : '오후';
    return '$period $hour:$minute';
  }

  Future<void> _pickTime(int idx) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[idx],
    );
    if (picked != null) {
      setState(() {
        _times[idx] = picked;
        _times.sort(
          (a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute),
        );
      });
    }
  }

  void _medicineListener() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _medicineController.removeListener(_medicineListener);
    _medicineController.addListener(_medicineListener);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopCurveClipper(),
              child: Container(height: 300, color: const Color(0xFFFFEBEE)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AlarmHeader(showBackButton: true),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '어떤 약을 드시나요?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _medicineController,
                    decoration: InputDecoration(
                      hintText: '약 이름을 입력 해주세요',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: _isMedicineEmpty
                          ? Colors.grey[200]
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '복용 날짜를 선택해주세요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _toggleAllDays,
                        icon: Icon(
                          _allDaysSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.pink,
                        ),
                        label: const Text(
                          '전체선택',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _allDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return GestureDetector(
                        onTap: () => _toggleDay(day),
                        child: Container(
                          width: 40,
                          height: 48,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.pinkAccent
                                : const Color(0xFF9E9E9E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '복용 시간을 알려주세요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.black),
                            onPressed: _removeTime,
                            color: Colors.black,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.black),
                            onPressed: _addTime,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ..._times.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        onTap: () => _pickTime(idx),
                        child: AbsorbPointer(
                          child: TextField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: _formatTimeOfDay(t),
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'NFC 태그에 해당 약을 연동 할까요?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '알람의 강제성이 높아져 복용을 잊지 않고 할 수 있어요',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _nfcEnabled = !_nfcEnabled;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[200],
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'NFC 연동하기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final name = _medicineController.text.trim();
                      final times = List<TimeOfDay>.from(_times);
                      if (name.length < 1 || name.length > 255) {
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('안내'),
                            content: const Text('약 이름은 1~255자 사이여야 합니다.'),
                            backgroundColor: Colors.white,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      if (name.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('안내'),
                            content: const Text('약 이름을 입력해 주세요.'),
                            backgroundColor: Colors.white,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      if (_selectedDays.isEmpty) {
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('안내'),
                            content: const Text('복용 요일을 1개 이상 선택해 주세요.'),
                            backgroundColor: Colors.white,
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      if (times.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('안내'),
                            content: const Text('복용 시간을 1개 이상 입력해 주세요.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      late final MedicineAlarm alarm;
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final scheduleService = ScheduleService();
                        final now = DateTime.now();
                        final startDate =
                            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                        final timeStrings = times
                            .map(
                              (t) =>
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                            )
                            .toList();
                        const dayEnumMap = {
                          '월': 'MON',
                          '화': 'TUE',
                          '수': 'WED',
                          '목': 'THU',
                          '금': 'FRI',
                          '토': 'SAT',
                          '일': 'SUN',
                        };
                        final repeatDays = _selectedDays
                            .map((d) => dayEnumMap[d])
                            .whereType<String>()
                            .toList();
                        final body = {
                          'medication_name': name,
                          'times': timeStrings,
                          'repeat_days': repeatDays,
                          'start_date': startDate,
                        };
                        if (widget.initialAlarm == null) {
                          final created = await scheduleService.createSchedule(
                            body,
                          );
                          final createdMap = created as Map<String, dynamic>;
                          final scheduleId = (createdMap['id'] as num).toInt();
                          final everyDay = _selectedDays.length == 7;
                          alarm = MedicineAlarm(
                            id: scheduleId.toString(),
                            name: name,
                            times: times,
                            days: List.from(_selectedDays),
                            everyDay: everyDay,
                            nfcEnabled: _nfcEnabled,
                          );
                        } else {
                          final scheduleId = int.tryParse(
                            widget.initialAlarm!.id,
                          );
                          if (scheduleId == null) {
                            throw Exception('기존 알람 ID가 유효하지 않습니다.');
                          }
                          await scheduleService.updateSchedule(
                            scheduleId,
                            body,
                          );
                          final everyDay = _selectedDays.length == 7;
                          alarm = MedicineAlarm(
                            id: widget.initialAlarm!.id,
                            name: name,
                            times: times,
                            days: List.from(_selectedDays),
                            everyDay: everyDay,
                            nfcEnabled: _nfcEnabled,
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _isLoading = false;
                        });
                        if (mounted) {
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('오류'),
                              content: Text('스케줄 생성에 실패했습니다. 다시 시도해주세요.\n$e'),
                              backgroundColor: Colors.white,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                        }
                        return;
                      }

                      final alarmService = AlarmService();
                      final success = await alarmService.scheduleAlarm(alarm);

                      setState(() {
                        _isLoading = false;
                      });

                      if (success) {
                        if (mounted) {
                          Navigator.pop(context, alarm);
                        }
                      } else {
                        if (mounted) {
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('안내'),
                              content: const Text('알람 등록에 실패했습니다. 다시 시도해주세요.'),
                              backgroundColor: Colors.white,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '등록하기',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
