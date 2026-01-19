import 'package:flutter/material.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_day_widgets.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';

/// 주간 스트립 위젯
class WeekStrip extends StatelessWidget {
  final DateTime? selectedDay;
  final void Function(DateTime) onDaySelected;
  final Map<DateTime, int> totalByDay;
  final Map<DateTime, int> doneByDay;

  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.totalByDay,
    required this.doneByDay,
  });

  String _weekdayKor(int weekday) {
    const arr = ['월', '화', '수', '목', '금', '토', '일'];
    return arr[(weekday + 6) % 7];
  }

  Widget _buildBaseDay(DateTime day, Color primaryBlue) {
    final key = dateKey(day);
    final today = DateTime.now();
    final todayKey = dateKey(today);
    final isFuture = key.isAfter(todayKey);
    final total = totalByDay[key] ?? 0;
    final done = doneByDay[key] ?? 0;
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

    if (selectedDay == null) return const SizedBox.shrink();
    final sel = selectedDay!;
    final startOfWeek = sel.subtract(Duration(days: (sel.weekday % 7)));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    Widget dayItem(DateTime d) {
      final isSelected =
          selectedDay != null && dateKey(d) == dateKey(selectedDay!);
      final total = totalByDay[dateKey(d)] ?? 0;
      final done = doneByDay[dateKey(d)] ?? 0;
      return GestureDetector(
        onTap: () {
          onDaySelected(d);
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
                  ? FilledDay(
                      text: d.day.toString(),
                      bg: primaryBlue,
                      fg: Colors.white,
                    )
                  : OutlinedDay(text: d.day.toString(), color: primaryBlue)
            else
              _buildBaseDay(d, primaryBlue),
          ],
        ),
      );
    }

    void moveWeek(int deltaDays) {
      final newSelected = sel.add(Duration(days: deltaDays));
      onDaySelected(newSelected);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -100) {
          moveWeek(7); // 왼쪽으로 스와이프 → 다음 주
        } else if (v > 100) {
          moveWeek(-7); // 오른쪽으로 스와이프 → 이전 주
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map(dayItem).toList(),
        ),
      ),
    );
  }
}



