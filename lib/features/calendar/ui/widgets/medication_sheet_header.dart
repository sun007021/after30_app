import 'package:flutter/material.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';

/// 약물 시트의 헤더 위젯 (날짜와 진행률 표시)
class MedicationSheetHeader extends StatelessWidget {
  final DateTime? selectedDay;
  final int total;
  final int done;

  const MedicationSheetHeader({
    super.key,
    required this.selectedDay,
    required this.total,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);

    if (selectedDay == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                '${selectedDay!.year.toString().padLeft(4, '0')}.${selectedDay!.month.toString().padLeft(2, '0')}.${selectedDay!.day.toString().padLeft(2, '0')} (${weekdayKor(selectedDay!.weekday)})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (total > 0)
              Positioned(
                right: 0,
                child: Builder(
                  builder: (_) {
                    final double frac = (done / total).clamp(0.0, 1.0);
                    return SizedBox(
                      width: 72,
                      height: 26,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(color: const Color(0xFFC1D1FF)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: frac,
                                child: Container(color: primaryBlue),
                              ),
                            ),
                            Text(
                              '$done/$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
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
    );
  }
}
