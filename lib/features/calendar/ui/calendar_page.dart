import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _DayMark { none, scheduled, completed }

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

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    _loadMonth(_focusedDay);
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
      for (final m in meds) {
        final key = DateTime(m.date.year, m.date.month, m.date.day);
        totalsByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        if ((m.status).toLowerCase() == 'taken') {
          completedByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      if (!mounted) return;
      setState(() {
        _totalByDay
          ..clear()
          ..addAll(totalsByDay);
        _doneByDay
          ..clear()
          ..addAll(completedByDay);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _totalByDay.clear();
        _doneByDay.clear();
      });
    }
  }

  Widget _buildBaseDay(DateTime day, Color primaryBlue) {
    final key = DateTime(day.year, day.month, day.day);
    final total = _totalByDay[key] ?? 0;
    final done = _doneByDay[key] ?? 0;
    final text = day.day.toString();
    if (total == 0) {
      return Center(child: Text(text, style: const TextStyle(fontSize: 14)));
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                          },
                        ),
                        Text(
                          '${_focusedDay.year}년 ${_focusedDay.month.toString().padLeft(2, '0')}월',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
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
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                        _loadMonth(focusedDay);
                      },
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      daysOfWeekHeight: 24,
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          const labels = ['일', '월', '화', '수', '목', '금', '토'];
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
                          final key = DateTime(day.year, day.month, day.day);
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
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: lightBlueBg),
              ),
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
