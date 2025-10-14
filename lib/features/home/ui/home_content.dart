import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/common/topbar.dart';
import 'package:dotted_border/dotted_border.dart';

class HomeContent extends StatefulWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final Set<String> _completedDoseKeys = <String>{};

  DateTime _selectedDate = DateTime.now();
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDosesForDate(_selectedDate);
    _loadCompletedFromServer(_selectedDate);
  }

  Future<void> _loadDosesForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await MedicationService.fetchMedications(date, date);
      setState(() {
        _medications = items
            .where(
              (m) =>
                  m.date.year == date.year &&
                  m.date.month == date.month &&
                  m.date.day == date.day,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompletedFromServer(DateTime date) async {
    try {
      final hs = HistoryService();
      final ymd = _yyyymmdd(date);
      final list = await hs.getUserHistories(
        startDate:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        endDate:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
      final next = <String>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (status == 'taken') {
          final scheduleId = (m['schedule_id'] as num?)?.toInt();
          final timeStr = (m['scheduled_time'] ?? '00:00').toString();
          if (scheduleId != null) {
            next.add('${scheduleId}_${ymd}_$timeStr');
          }
        }
      }
      if (mounted) {
        setState(() {
          _completedDoseKeys
            ..clear()
            ..addAll(next);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _completedDoseKeys.clear();
        });
      }
    }
  }

  Future<void> _goToRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineRegisterPage()),
    );
    // 등록/수정 여부와 무관하게 서버 기준으로 다시 로드
    await _loadDosesForDate(_selectedDate);
    await _loadCompletedFromServer(_selectedDate);
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
    _loadDosesForDate(_selectedDate);
    _loadCompletedFromServer(_selectedDate);
  }

  Future<void> _markCompleted(String doseKey) async {
    // doseKey: `${scheduleId}_${yyyymmdd}_${HH:mm[:ss]}`
    try {
      final parts = doseKey.split('_');
      if (parts.length >= 3) {
        final scheduleId = int.tryParse(parts[0]);
        // 날짜는 _selectedDate 기준으로 yyyy-MM-dd 생성
        final dateStr =
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'
                .toString();
        final timeStr = parts[2];
        if (scheduleId != null) {
          final hs = HistoryService();
          await hs.markTaken(
            scheduleId: scheduleId,
            scheduledDate: dateStr,
            scheduledTime: timeStr,
          );
          await _loadDosesForDate(_selectedDate);
          await _loadCompletedFromServer(_selectedDate);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  String _formatKoreanDate(DateTime d) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = days[(d.weekday + 6) % 7];
    return '${d.month}/${d.day} ($weekday)';
  }

  // 시간 유틸 제거됨 (서버 문자열 사용)

  String _yyyymmdd(DateTime d) {
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<Medication> dayMeds = [..._medications]
      ..sort((a, b) => a.time.compareTo(b.time));
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0FF),
      body: SafeArea(
        child: Stack(
          children: [
            // 본문 레이어
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 본문 스크롤
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단 흰 배경 바 + 알람 아이콘
                        const AlarmTopBar(),
                        const SizedBox(height: 8),
                        // 상단 파란 배경 스트립 + 타이틀
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            left: 22,
                            right: 16,
                            top: 5,
                            bottom: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '나의 복약 체크 리스트',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 날짜 선택 바
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () => _changeDate(-1),
                                      icon: SvgPicture.asset(
                                        'assets/images/chevron_left.svg',
                                        width: 8,
                                        height: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatKoreanDate(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _changeDate(1),
                                      icon: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..scale(-1.0, 1.0, 1.0),
                                        child: SvgPicture.asset(
                                          'assets/images/chevron_left.svg',
                                          width: 8,
                                          height: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.only(left: 20),
                                  child: Text(
                                    '오늘의 복약',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
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
                                else if (dayMeds.isEmpty)
                                  _EmptyMedicineSection(onAdd: _goToRegister)
                                else ...[
                                  // 선택한 날짜의 알람만 표시
                                  if (dayMeds.isEmpty)
                                    _EmptyMedicineSection(
                                      onAdd: _goToRegister,
                                      title: '해당 날짜에 복약 일정이 없어요',
                                    )
                                  else ...[
                                    // 약 목록 렌더링
                                    ...dayMeds.map((m) {
                                      final timeLabel = m.time.substring(0, 5);
                                      final isCompleted = m.status == 'taken';
                                      final doseKey =
                                          '${m.scheduleId ?? m.id}_${_yyyymmdd(_selectedDate)}_${m.time}';
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          side: const BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        elevation: 0,
                                        color: Colors.white,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(timeLabel),
                                                  const Spacer(),
                                                  if (!isCompleted)
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          _markCompleted(
                                                            doseKey,
                                                          ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF4F7EFF,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 8,
                                                            ),
                                                        minimumSize: const Size(
                                                          0,
                                                          36,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      child: const Text(
                                                        '복용 완료',
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    isCompleted
                                                        ? Icons.task_alt
                                                        : Icons.access_time,
                                                    color: isCompleted
                                                        ? const Color(
                                                            0xFF1A73E8,
                                                          )
                                                        : Colors.black38,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isCompleted
                                                        ? '복용 완료'
                                                        : '복용 미완료',
                                                    style: TextStyle(
                                                      color: isCompleted
                                                          ? const Color(
                                                              0xFF1A73E8,
                                                            )
                                                          : Colors.black45,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                m.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                  const SizedBox(height: 8),
                                  _AddMedicineTile(onTap: _goToRegister),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Container(height: 120, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: DottedBorder(
          color: const Color(0xFFBDBDBD),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white),
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
      ),
    );
  }
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
