import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_day_widgets.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';
import 'package:after30/features/calendar/ui/widgets/pinned_header_delegate.dart';
import 'package:after30/features/calendar/ui/widgets/medication_tile.dart';
import 'package:after30/features/calendar/ui/widgets/week_strip.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_month_header.dart';
import 'package:after30/features/calendar/ui/widgets/medication_sheet_header.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, int> _totalByDay = {};
  final Map<DateTime, int> _doneByDay = {};
  final Map<DateTime, List<Medication>> _medsByDay = {};
  bool _sheetVisible = false;
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  final GlobalKey _monthHeaderKey = GlobalKey();
  final GlobalKey _calendarCardKey = GlobalKey();
  double? _maxSheetFraction;
  double? _minInitialSheetFraction;

  @override
  void initState() {
    super.initState();
    // 첫 진입 시 오늘 날짜를 선택하고 시트를 보이도록 설정
    _selectedDay = dateKey(_focusedDay);
    _sheetVisible = true;
    _loadMonth(_focusedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateSheetFractions();
    });
  }

  void _recalculateSheetFractions() {
    if (!_sheetVisible) return; // 시트가 보일 때만 계산애니메이션
    final headerCtx = _monthHeaderKey.currentContext;
    final cardCtx = _calendarCardKey.currentContext;
    if (headerCtx == null || cardCtx == null) return;
    final headerBox = headerCtx.findRenderObject() as RenderBox?;
    final cardBox = cardCtx.findRenderObject() as RenderBox?;
    if (headerBox == null || cardBox == null) return;
    final headerTop = headerBox.localToGlobal(Offset.zero).dy;
    // 카드 위치는 현재 초기 위치 계산에 직접 사용하지 않음 (향후 확장 대비 측정 유지)
    final screenHeight = MediaQuery.of(context).size.height;

    final maxFraction = ((screenHeight - headerTop) / screenHeight).clamp(
      0.38,
      0.95,
    );
    // 초기 위치를 화면 "맨 아래"에 가깝게 (핸들바만 보이도록) 고정
    // max 대비 여유는 0.02 남김
    final initialFraction = (0.38).clamp(0.1, maxFraction - 0.02);

    if (!mounted) return;
    setState(() {
      _maxSheetFraction = maxFraction;
      _minInitialSheetFraction = initialFraction;
    });
    // 첫 프레임에서도 아래 위치로 보장
    try {
      if (_minInitialSheetFraction != null) {
        // 이미 사용자가 시트를 더 올려둔 상태라면, 현재 위치를 유지하고 내려가지 않도록 함
        final current = _dragController.size;
        if (current <= (_minInitialSheetFraction! + 0.001)) {
          _dragController.animateTo(
            _minInitialSheetFraction!,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth(DateTime anyDayInMonth) async {
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    try {
      final List<Medication> meds = await MedicationService.fetchMedications(
        first,
        last,
      );
      final totalsByDay = <DateTime, int>{};
      final completedByDay = <DateTime, int>{};
      final medsByDay = <DateTime, List<Medication>>{};
      for (final m in meds) {
        final key = dateKey(m.date);
        totalsByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        if ((m.status).toLowerCase() == 'taken') {
          completedByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        }
        medsByDay.putIfAbsent(key, () => <Medication>[]).add(m);
      }
      if (!mounted) return;
      setState(() {
        _totalByDay
          ..clear()
          ..addAll(totalsByDay);
        _doneByDay
          ..clear()
          ..addAll(completedByDay);
        _medsByDay
          ..clear()
          ..addAll(medsByDay);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _totalByDay.clear();
        _doneByDay.clear();
        _medsByDay.clear();
      });
    }
  }

  Widget _buildBaseDay(DateTime day, Color primaryBlue) {
    final key = dateKey(day);
    final today = DateTime.now();
    final todayKey = dateKey(today);
    final isFuture = key.isAfter(todayKey);
    final total = _totalByDay[key] ?? 0;
    final done = _doneByDay[key] ?? 0;
    final text = day.day.toString();
    // 미래 날짜는 게이지 숨김 (월간/주간 공통 정책)
    if (isFuture) {
      return Center(
        child: Container(
          width: kDaySize,
          height: kDaySize,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (total == 0) {
      return Center(
        child: Container(
          width: kDaySize,
          height: kDaySize,
          alignment: Alignment.center,
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      );
    }
    if (done >= total) {
      return FilledDay(text: text, bg: primaryBlue, fg: Colors.white);
    }
    final percent = total > 0 ? (done / total) : 0.0;
    return GaugeDay(
      text: text,
      percent: percent,
      track: const Color(0xFFEDEFF2),
      progress: primaryBlue,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    const lightBlueBg = Color(0xFFEAF2FF);

    List<Medication> medsForSelected() {
      final key = _selectedDay != null ? dateKey(_selectedDay!) : null;
      if (key == null) return const [];
      return _medsByDay[key] ?? const [];
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  key: _calendarCardKey,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                    child: Column(
                      children: [
                        CalendarMonthHeader(
                          focusedDay: _focusedDay,
                          monthHeaderKey: _monthHeaderKey,
                          onPreviousMonth: () {
                            final prev = DateTime(
                              _focusedDay.year,
                              _focusedDay.month - 1,
                              1,
                            );
                            setState(() => _focusedDay = prev);
                            _loadMonth(prev);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                          onNextMonth: () {
                            final next = DateTime(
                              _focusedDay.year,
                              _focusedDay.month + 1,
                              1,
                            );
                            setState(() => _focusedDay = next);
                            _loadMonth(next);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                        ),
                        TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100, 12, 31),
                          focusedDay: _focusedDay,
                          headerVisible: false,
                          sixWeekMonthsEnforced: true,
                          rowHeight: 48,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          selectedDayPredicate: (d) =>
                              _selectedDay != null &&
                              d.year == _selectedDay!.year &&
                              d.month == _selectedDay!.month &&
                              d.day == _selectedDay!.day,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = dateKey(selectedDay);
                              _focusedDay = focusedDay;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _sheetVisible = true;
                              });
                              _recalculateSheetFractions();
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay);
                            _loadMonth(focusedDay);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                          ),
                          daysOfWeekHeight: 28,
                          calendarBuilders: CalendarBuilders(
                            dowBuilder: (context, day) {
                              const labels = [
                                '일',
                                '월',
                                '화',
                                '수',
                                '목',
                                '금',
                                '토',
                              ];
                              final label = labels[day.weekday % 7];
                              return Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                            selectedBuilder: (context, day, focusedDay) {
                              // 선택된 날짜에는 게이지 숨김: 모두 완료면 꽉 찬 파란 원, 아니면 테두리만
                              final key = dateKey(day);
                              final total = _totalByDay[key] ?? 0;
                              final done = _doneByDay[key] ?? 0;
                              if (total > 0 && done >= total) {
                                return FilledDay(
                                  text: day.day.toString(),
                                  bg: primaryBlue,
                                  fg: Colors.white,
                                );
                              }
                              return OutlinedDay(
                                text: day.day.toString(),
                                color: primaryBlue,
                              );
                            },
                            defaultBuilder: (context, day, focusedDay) {
                              return _buildBaseDay(day, primaryBlue);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 3, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: lightBlueBg),
                  ),
                ),
              ],
            ),
            // 비모달 드래그 시트: 초기엔 숨김, 날짜 선택 후 표시
            if (_sheetVisible)
              DraggableScrollableSheet(
                controller: _dragController,
                expand: false,
                snap: true,
                snapSizes: [(_minInitialSheetFraction ?? 0.38), 1.0],
                minChildSize: (_minInitialSheetFraction ?? 0.38),
                initialChildSize: (_minInitialSheetFraction ?? 0.38),
                maxChildSize: 1.0,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              // handle bar
                              Container(
                                width: 64,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              MedicationSheetHeader(
                                selectedDay: _selectedDay,
                                total: _selectedDay != null
                                    ? (_totalByDay[dateKey(_selectedDay!)] ?? 0)
                                    : 0,
                                done: _selectedDay != null
                                    ? (_doneByDay[dateKey(_selectedDay!)] ?? 0)
                                    : 0,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: 64,
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.centerLeft,
                              child: WeekStrip(
                                selectedDay: _selectedDay,
                                onDaySelected: (d) {
                                  setState(() {
                                    _selectedDay = dateKey(d);
                                    _focusedDay = d;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_sheetVisible)
                                      _recalculateSheetFractions();
                                  });
                                },
                                totalByDay: _totalByDay,
                                doneByDay: _doneByDay,
                              ),
                            ),
                          ),
                        ),
                        //주간, 약 목록 간격
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        Builder(
                          builder: (_) {
                            final list = medsForSelected();
                            if (list.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    '선택한 날짜에 기록이 없습니다',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  return MedicationTile(
                                    medication: list[index],
                                    selectedDay: _selectedDay,
                                  );
                                }, childCount: list.length),
                              ),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 3),
    );
  }
}
