import 'package:flutter/material.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/utils/responsive.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';

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

  int get _currentStep {
    final hasName = _medicineController.text.trim().isNotEmpty;
    final hasDays = _selectedDays.isNotEmpty;
    if (!hasName) return 1;
    if (!hasDays) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    final alarm = widget.initialAlarm;
    _medicineController = TextEditingController(text: alarm?.name ?? '');
    _selectedDays = alarm?.days ?? [];
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
        DoubleCheckDialog.showSingle(
          context: context,
          title: '안내',
          message: '복용 시간은 최소 1개 이상 입력해야 합니다.',
        );
      } else {
        _times.removeLast();
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hh = tod.hour.toString().padLeft(2, '0');
    final mm = tod.minute.toString().padLeft(2, '0');
    return '알람 $hh:$mm';
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
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 0),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: Responsive.responsivePadding(context, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  StepHeader(currentStep: _currentStep),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '1. 어떤 약을 드시나요?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _medicineController,
                    decoration: InputDecoration(
                      hintText: '약 이름을 입력 해주세요',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: _isMedicineEmpty
                          ? Colors.grey[200]
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 55),
                  const Text(
                    '2. 복용 날짜를 선택해주세요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      const Text('전체선택'),
                      Checkbox(
                        value: _allDaysSelected,
                        onChanged: (_) => _toggleAllDays(),
                        activeColor: const Color(0xFF235DFF),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: Responsive.responsiveValue(context, 10),
                    runSpacing: Responsive.responsiveValue(context, 8),
                    alignment: WrapAlignment.start,
                    children: _allDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return GestureDetector(
                        onTap: () => _toggleDay(day),
                        child: Container(
                          width: Responsive.responsiveValue(context, 44),
                          height: Responsive.responsiveValue(context, 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF235DFF)
                                : Colors.white,
                            border: Border.all(
                              color: const Color(0xFF235DFF),
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF235DFF),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 45),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '3. 복용 시간을 알려주세요',
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
                  const SizedBox(height: 15),
                  ..._times.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
                  // NFC 섹션 제거
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final name = _medicineController.text.trim();
                      final times = List<TimeOfDay>.from(_times);
                      final hasMissing =
                          name.isEmpty ||
                          _selectedDays.isEmpty ||
                          times.isEmpty;
                      if (hasMissing) {
                        await DoubleCheckDialog.showSingle(
                          context: context,
                          title: '아직 입력되지 않은 정보가 있어요.',
                          message: '복약 시간이나 약 이름을 입력해야 정확한 알림을 드릴 수 있어요.',
                        );
                        return;
                      }
                      if (name.length > 255) {
                        await DoubleCheckDialog.showSingle(
                          context: context,
                          title: '안내',
                          message: '약 이름은 1~255자 사이여야 합니다.',
                        );
                        return;
                      }
                      final isEdit = widget.initialAlarm != null;
                      final confirmed = await DoubleCheckDialog.show(
                        context: context,
                        title: isEdit ? '수정한 내용을 저장할까요?' : '약을 등록하시겠습니까?',
                        message: isEdit
                            ? '변경된 복약 시간은 다음 알림부터 바로 적용됩니다.'
                            : '입력하신 시간에 맞춰 잊지 않도록 알림을 보내드릴게요.',
                        confirmLabel: isEdit ? '저장' : '등록',
                        cancelLabel: '취소',
                      );
                      if (!confirmed) return;
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
                      backgroundColor: const Color(0xFF235DFF),
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
