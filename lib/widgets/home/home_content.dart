import 'package:flutter/material.dart';
import 'package:after30/widgets/common/navigationBar.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/services/alarm_service.dart';
import 'package:after30/models/medicine_alarm.dart';
import 'package:after30/screens/family/family_page.dart';
import 'package:after30/screens/alarm/add_alarm.dart';
import 'package:after30/services/completion_store.dart';

class HomeContent extends StatefulWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final AlarmService _alarmService = AlarmService();
  final Set<String> _completedDoseKeys = <String>{};

  DateTime _selectedDate = DateTime.now();
  List<MedicineAlarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _loadCompleted();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final alarms = await _alarmService.getAlarms();
      setState(() {
        _alarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompleted() async {
    final set = await CompletionStore.loadCompletedSet();
    if (mounted) {
      setState(() {
        _completedDoseKeys
          ..clear()
          ..addAll(set);
      });
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

  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
  }

  void _markCompleted(String doseKey) {
    setState(() {
      _completedDoseKeys.add(doseKey);
    });
    // 영구 저장 (달력 페이지 연동용)
    CompletionStore.markCompleted(doseKey);
  }

  String _formatKoreanDate(DateTime d) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = days[(d.weekday + 6) % 7];
    return '${d.month}/${d.day} ($weekday)';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? '오전' : '오후';
    return '$period $hour:$minute';
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _isAlarmScheduledOnDate(MedicineAlarm alarm, DateTime date) {
    if (alarm.everyDay) return true;
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final dayStr = days[(date.weekday + 6) % 7];
    return alarm.days.contains(dayStr);
  }

  String _yyyymmdd(DateTime d) {
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<MedicineAlarm> visibleAlarms = _alarms
        .where((a) => _isAlarmScheduledOnDate(a, _selectedDate) && a.isActive)
        .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 가족 섹션 (가족이 없으므로 + 동그라미만 표시)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _AddCircleButton(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FamilyPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // 본문 스크롤
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      '나의 복약 체크 리스트',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 날짜 선택 바
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _changeDate(-1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(
                                  _formatKoreanDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeDate(1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Text(
                                '오늘의 복약',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_alarms.isEmpty)
                              _EmptyMedicineSection(onAdd: _goToRegister)
                            else ...[
                              // 선택한 날짜의 알람만 표시
                              if (visibleAlarms.isEmpty)
                                _EmptyMedicineSection(
                                  onAdd: _goToRegister,
                                  title: '해당 날짜에 복약 일정이 없어요',
                                )
                              else ...[
                                // 시간별로 전개 및 정렬
                                ...(() {
                                  final List<_DoseItem> doses = [];
                                  for (final alarm in visibleAlarms) {
                                    for (final t in alarm.times) {
                                      doses.add(
                                        _DoseItem(alarm: alarm, time: t),
                                      );
                                    }
                                  }
                                  doses.sort(
                                    (a, b) => _timeToMinutes(
                                      a.time,
                                    ).compareTo(_timeToMinutes(b.time)),
                                  );
                                  return doses.map((dose) {
                                    final dateKey = _yyyymmdd(_selectedDate);
                                    final timeKey =
                                        '${dose.time.hour.toString().padLeft(2, '0')}:${dose.time.minute.toString().padLeft(2, '0')}';
                                    final doseKey =
                                        '${dose.alarm.id}_${dateKey}_${timeKey}';
                                    final isCompleted = _completedDoseKeys
                                        .contains(doseKey);
                                    return _MedicineCard(
                                      alarm: dose.alarm,
                                      isCompleted: isCompleted,
                                      onComplete: () => _markCompleted(doseKey),
                                      timeLabel: _formatTimeOfDay(dose.time),
                                    );
                                  }).toList();
                                })(),
                              ],
                              const SizedBox(height: 8),
                              _AddMedicineTile(onTap: _goToRegister),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }
}

class _AddCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCircleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFEAF2FF),
          border: Border.all(color: const Color(0xFFBFD4FF)),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Color(0xFF1A73E8), size: 28),
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineAlarm alarm;
  final bool isCompleted;
  final VoidCallback onComplete;
  final String timeLabel;

  const _MedicineCard({
    required this.alarm,
    required this.isCompleted,
    required this.onComplete,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isCompleted
        ? const Color(0xFFB3D5FF)
        : const Color(0xFFE0E0E0);
    final Color background = isCompleted
        ? const Color(0xFFEAF2FF)
        : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.task_alt : Icons.access_time,
                  color: isCompleted ? const Color(0xFF1A73E8) : Colors.black38,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted ? '복용 완료' : '복용 미완료',
                  style: TextStyle(
                    color: isCompleted
                        ? const Color(0xFF1A73E8)
                        : Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alarm.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 12),
            if (!isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F7EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('복용 완료'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddMedicineTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMedicineTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: Column(
            children: const [
              Icon(Icons.add, color: Colors.black54),
              SizedBox(height: 4),
              Text('추가하기', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoseItem {
  final MedicineAlarm alarm;
  final TimeOfDay time;
  _DoseItem({required this.alarm, required this.time});
}

class _EmptyMedicineSection extends StatelessWidget {
  final VoidCallback onAdd;
  final String? title;
  const _EmptyMedicineSection({required this.onAdd, this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.medication, size: 60, color: Colors.black54),
          const SizedBox(height: 8),
          Text(
            title ?? '등록된 약이 없어요',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('약 등록하기'),
          ),
        ],
      ),
    );
  }
}
