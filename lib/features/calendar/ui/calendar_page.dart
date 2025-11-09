import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:flutter_svg/flutter_svg.dart';

const double _kDaySize = 33.0;
const double _kGaugeStroke = 5.0;

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
    _selectedDay = null; // 첫 진입 시에는 선택 없음
    _loadMonth(_focusedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateSheetFractions();
    });
  }

  DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  void _recalculateSheetFractions() {
    if (!_sheetVisible) return; // 시트가 보일 때만 계산/애니메이션
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
      0.4,
      0.95,
    );
    // 초기 위치를 화면 "맨 아래"에 가깝게 (핸들바만 보이도록) 고정
    // max 대비 여유는 0.02 남김
    final initialFraction = (0.40).clamp(0.1, maxFraction - 0.02);

    if (!mounted) return;
    setState(() {
      _maxSheetFraction = maxFraction;
      _minInitialSheetFraction = initialFraction;
    });
    // 첫 프레임에서도 아래 위치로 보장
    try {
      if (_minInitialSheetFraction != null) {
        _dragController.animateTo(
          _minInitialSheetFraction!,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
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
        final key = DateTime(m.date.year, m.date.month, m.date.day);
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
    final key = DateTime(day.year, day.month, day.day);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final isFuture = key.isAfter(todayKey);
    final total = _totalByDay[key] ?? 0;
    final done = _doneByDay[key] ?? 0;
    final text = day.day.toString();
    // 미래 날짜는 게이지 숨김 (월간/주간 공통 정책)
    if (isFuture) {
      return Center(
        child: Container(
          width: _kDaySize,
          height: _kDaySize,
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
          width: _kDaySize,
          height: _kDaySize,
          alignment: Alignment.center,
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      );
    }
    if (done >= total) {
      return _FilledDay(text: text, bg: primaryBlue, fg: Colors.white);
    }
    final percent = total > 0 ? (done / total) : 0.0;
    return _GaugeDay(
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
      final key = _selectedDay != null ? _dateKey(_selectedDay!) : null;
      if (key == null) return const [];
      return _medsByDay[key] ?? const [];
    }

    String _weekdayKor(int weekday) {
      const arr = ['월', '화', '수', '목', '금', '토', '일'];
      return arr[(weekday + 6) % 7];
    }

    Widget _weekStrip() {
      if (_selectedDay == null) return const SizedBox.shrink();
      final sel = _selectedDay!;
      final startOfWeek = sel.subtract(Duration(days: (sel.weekday % 7)));
      final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

      Widget dayItem(DateTime d) {
        final isSelected =
            _selectedDay != null && _dateKey(d) == _dateKey(_selectedDay!);
        final total = _totalByDay[_dateKey(d)] ?? 0;
        final done = _doneByDay[_dateKey(d)] ?? 0;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = _dateKey(d);
              _focusedDay = d;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_sheetVisible) _recalculateSheetFractions();
            });
          },
          child: Column(
            children: [
              Text(
                _weekdayKor(d.weekday),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              if (isSelected)
                (total > 0 && done >= total)
                    ? _FilledDay(
                        text: d.day.toString(),
                        bg: primaryBlue,
                        fg: Colors.white,
                      )
                    : _OutlinedDay(text: d.day.toString(), color: primaryBlue)
              else
                _buildBaseDay(d, primaryBlue),
            ],
          ),
        );
      }

      void moveWeek(int deltaDays) {
        final newSelected = sel.add(Duration(days: deltaDays));
        setState(() {
          _selectedDay = _dateKey(newSelected);
          _focusedDay = newSelected;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_sheetVisible) _recalculateSheetFractions();
        });
      }

      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 기존 간격/레이아웃은 그대로 유지
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map(dayItem).toList(),
            ),
          ),
          // 좌우 페이지네이션 버튼 - 오버레이로 배치하여 간격에 영향 주지 않음
          Positioned(
            //
            left: -28,
            top: 12,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: SvgPicture.asset(
                'assets/images/chevron_left.svg',
                width: 9,
                height: 14,
              ),
              onPressed: () => moveWeek(-7),
            ),
          ),
          Positioned(
            right: -28,
            top: 12,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                child: SvgPicture.asset(
                  'assets/images/chevron_left.svg',
                  width: 9,
                  height: 14,
                ),
              ),
              onPressed: () => moveWeek(7),
            ),
          ),
        ],
      );
    }

    String _formatKorTime(String hhmm) {
      final parts = hhmm.split(':');
      int h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      final int m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final bool pm = h >= 12;
      final int h12 = h % 12 == 0 ? 12 : h % 12;
      return '${pm ? '오후' : '오전'} $h12:${m.toString().padLeft(2, '0')}';
    }

    String _formatHHmmKST(DateTime dt) {
      final kst = dt.add(const Duration(hours: 9));
      return '${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')}';
    }

    Widget _chip({
      required String text,
      Color bg = const Color(0xFFFCFCFC),
      Color fg = Colors.black87,
      Color? border,
      IconData? icon,
      Widget? leading,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 4),
            ] else if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      );
    }

    Widget _medicationTile(Medication m) {
      const primaryBlue = Color(0xFF235DFF);
      final bool isTaken = (m.status.toLowerCase() == 'taken');

      final BoxDecoration deco = BoxDecoration(
        color: isTaken ? const Color(0xFFEAF2FF) : const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTaken ? primaryBlue : const Color(0xFFDBDBDB),
          width: 1.5,
        ),
        boxShadow: isTaken
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      );

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: deco,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (isTaken)
                    _chip(
                      text: '알람 ${m.time}',
                      fg: Colors.black87,
                      bg: Colors.white,
                    )
                  else
                    _chip(
                      text: _formatKorTime(m.time),
                      fg: Colors.black54,
                      bg: const Color(0xFFFCFCFC),
                    ),
                  if (isTaken)
                    _chip(
                      text:
                          '복용 완료${m.takenAt != null ? ' ${_formatHHmmKST(m.takenAt!)}' : ''}',
                      fg: primaryBlue,
                      bg: Colors.white,
                      leading: SvgPicture.asset(
                        'assets/images/check.svg',
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          primaryBlue,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  else
                    _chip(
                      text: '복용 예정',
                      fg: Colors.black54,
                      bg: Colors.white,
                      icon: Icons.info_outline,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    child: isTaken
                        ? SvgPicture.asset(
                            'assets/images/alarmList_active.svg',
                            width: 45,
                            height: 45,
                          )
                        : SvgPicture.asset(
                            'assets/images/alarmList_deactive.svg',
                            width: 45,
                            height: 45,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: SvgPicture.asset(
                                'assets/images/chevron_left.svg',
                                width: 8,
                                height: 14,
                              ),
                              onPressed: () {
                                final prev = DateTime(
                                  _focusedDay.year,
                                  _focusedDay.month - 1,
                                  1,
                                );
                                setState(() => _focusedDay = prev);
                                _loadMonth(prev);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_sheetVisible)
                                    _recalculateSheetFractions();
                                });
                              },
                            ),
                            Text(
                              '${_focusedDay.year}년 ${_focusedDay.month.toString().padLeft(2, '0')}월',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              key: _monthHeaderKey,
                            ),
                            IconButton(
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
                              onPressed: () {
                                final next = DateTime(
                                  _focusedDay.year,
                                  _focusedDay.month + 1,
                                  1,
                                );
                                setState(() => _focusedDay = next);
                                _loadMonth(next);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_sheetVisible)
                                    _recalculateSheetFractions();
                                });
                              },
                            ),
                          ],
                        ),
                        TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100, 12, 31),
                          focusedDay: _focusedDay,
                          headerVisible: false,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          selectedDayPredicate: (d) =>
                              _selectedDay != null &&
                              d.year == _selectedDay!.year &&
                              d.month == _selectedDay!.month &&
                              d.day == _selectedDay!.day,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = DateTime(
                                selectedDay.year,
                                selectedDay.month,
                                selectedDay.day,
                              );
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
                          daysOfWeekHeight: 24,
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
                              final key = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                              final total = _totalByDay[key] ?? 0;
                              final done = _doneByDay[key] ?? 0;
                              if (total > 0 && done >= total) {
                                return _FilledDay(
                                  text: day.day.toString(),
                                  bg: primaryBlue,
                                  fg: Colors.white,
                                );
                              }
                              return _OutlinedDay(
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
                const SizedBox(height: 1),
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
                snapSizes: [
                  (_minInitialSheetFraction ?? 0.40),
                  (_maxSheetFraction ?? 0.7),
                ],
                minChildSize: (_minInitialSheetFraction ?? 0.40),
                initialChildSize: (_minInitialSheetFraction ?? 0.40),
                maxChildSize: (_maxSheetFraction ?? 0.7),
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
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
                              if (_selectedDay != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: SizedBox(
                                    height: 28,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Center(
                                          child: Text(
                                            '${_selectedDay!.year.toString().padLeft(4, '0')}.${_selectedDay!.month.toString().padLeft(2, '0')}.${_selectedDay!.day.toString().padLeft(2, '0')} (${_weekdayKor(_selectedDay!.weekday)})',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          child: Builder(
                                            builder: (_) {
                                              final key = _dateKey(
                                                _selectedDay!,
                                              );
                                              final total =
                                                  _totalByDay[key] ?? 0;
                                              final done = _doneByDay[key] ?? 0;
                                              if (total <= 0) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFDBDBDB,
                                                      ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    '기록 없음',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                );
                                              }
                                              final double frac = (done / total)
                                                  .clamp(0.0, 1.0);
                                              return SizedBox(
                                                width: 72,
                                                height: 26,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Container(
                                                        color: const Color(
                                                          0xFFD6E4FF,
                                                        ),
                                                      ),
                                                      Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: FractionallySizedBox(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          widthFactor: frac,
                                                          child: Container(
                                                            color: const Color(
                                                              0xFF235DFF,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '$done/$total',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedHeaderDelegate(
                            height: 64,
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.centerLeft,
                              child: _weekStrip(),
                            ),
                          ),
                        ),
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
                                  return _medicationTile(list[index]);
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

class _FilledDay extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _FilledDay({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: _kDaySize,
        height: _kDaySize,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _OutlinedDay extends StatelessWidget {
  final String text;
  final Color color;
  const _OutlinedDay({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: _kDaySize,
        height: _kDaySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GaugeDay extends StatelessWidget {
  final String text;
  final double percent;
  final Color track;
  final Color progress;
  const _GaugeDay({
    required this.text,
    required this.percent,
    required this.track,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0.0, 1.0);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: value),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        builder: (context, animated, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: _kDaySize,
                height: _kDaySize,
                child: CircularProgressIndicator(
                  value: animated,
                  strokeWidth: _kGaugeStroke,
                  backgroundColor: track,
                  color: progress,
                ),
              ),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          );
        },
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _PinnedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
