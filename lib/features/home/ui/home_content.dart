import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/common/topbar.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';
import 'package:after30/features/home/ui/widgets/empty_medicine_section.dart';
import 'package:after30/features/home/ui/widgets/add_medicine_tile.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';

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
      final ymd = yyyymmdd(date);
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
    try {
      final parts = doseKey.split('_');
      if (parts.length >= 3) {
        final scheduleId = int.tryParse(parts[0]);
        final dateStr =
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final timeStr = parts[2];
        if (scheduleId != null) {
          final hs = HistoryService();
          // 같은 일정/시간의 히스토리가 있으면 PUT으로 taken + taken_at 갱신,
          // 없으면 process API로 신규 완료 처리
          int? historyId;
          try {
            final list = await hs.getUserHistories(
              startDate: dateStr,
              endDate: dateStr,
            );
            for (final item in list) {
              if (item is! Map<String, dynamic>) continue;
              final sid = (item['schedule_id'] as num?)?.toInt();
              final scheduledTime = (item['scheduled_time'] ?? '').toString();
              if (sid == scheduleId &&
                  (scheduledTime == timeStr ||
                      scheduledTime.startsWith(timeStr))) {
                historyId = (item['id'] as num?)?.toInt();
                break;
              }
            }
          } catch (_) {}
          if (historyId != null) {
            await hs.updateHistoryStatus(
              historyId: historyId,
              status: 'taken',
              takenAt: DateTime.now(),
            );
          } else {
            await hs.markTaken(
              scheduleId: scheduleId,
              scheduledDate: dateStr,
              scheduledTime: timeStr,
            );
          }
          await _loadDosesForDate(_selectedDate);
          await _loadCompletedFromServer(_selectedDate);
        }
      }
    } catch (_) {}
  }

  Future<void> _markUncompleted(String doseKey) async {
    try {
      final parts = doseKey.split('_');
      if (parts.length >= 3) {
        final scheduleId = int.tryParse(parts[0]);
        final dateStr =
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final timeStr = parts[2];
        if (scheduleId != null) {
          final hs = HistoryService();
          // 선택한 날짜의 히스토리에서 해당 일정의 완료 기록을 찾아 ID로 상태 업데이트
          final list = await hs.getUserHistories(
            startDate: dateStr,
            endDate: dateStr,
          );
          int? historyId;
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final sid = (item['schedule_id'] as num?)?.toInt();
            final scheduledTime = (item['scheduled_time'] ?? '').toString();
            if (sid == scheduleId &&
                (scheduledTime == timeStr ||
                    scheduledTime.startsWith(timeStr))) {
              historyId = (item['id'] as num?)?.toInt();
              break;
            }
          }
          if (historyId != null) {
            await hs.updateHistoryStatus(
              historyId: historyId,
              status: 'cancelled',
            );
          }
          await _loadDosesForDate(_selectedDate);
          await _loadCompletedFromServer(_selectedDate);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<Medication> dayMeds = [..._medications]
      ..sort((a, b) => a.time.compareTo(b.time));
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 상단 영역 하늘색 배경
          Container(height: 220, color: const Color(0xFFEBF0FF)),
          // 본문 레이어
          SafeArea(
            child: Column(
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
                        // 상단 파란 배경 스트립 + 타이틀
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            left: 22,
                            right: 16,
                            bottom: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const PageTitle(
                            title: '나의 복약 체크 리스트',
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              24,
                              24,
                              24 + bottomSafe,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                HomeDateHeader(
                                  selectedDate: _selectedDate,
                                  onPreviousDay: () => _changeDate(-1),
                                  onNextDay: () => _changeDate(1),
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
                                  EmptyMedicineSection(onAdd: _goToRegister)
                                else ...[
                                  ...dayMeds.map((m) {
                                    final doseKey =
                                        '${m.scheduleId ?? m.id}_${yyyymmdd(_selectedDate)}_${m.time}';
                                    return MedicationDoseTile(
                                      medication: m,
                                      selectedDate: _selectedDate,
                                      doseKey: doseKey,
                                      onMarkCompleted: _markCompleted,
                                      onMarkUncompleted: _markUncompleted,
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  AddMedicineTile(onAdd: _goToRegister),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Container(
                          height: 120 + bottomSafe,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
