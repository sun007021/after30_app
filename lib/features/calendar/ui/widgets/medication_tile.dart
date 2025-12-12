import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/ui/widgets/chip_widget.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';

/// 약물 타일 위젯
class MedicationTile extends StatelessWidget {
  final Medication medication;
  final DateTime? selectedDay;

  const MedicationTile({super.key, required this.medication, this.selectedDay});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    const dangerRed = Color(0xFFE50000);
    final bool isTaken = (medication.status.toLowerCase() == 'taken');

    // 미복용 판단: 선택한 날짜가 과거이거나, 오늘이면서 예정 시각이 지났고 아직 완료 아님
    bool isMissed = false;
    try {
      if (!isTaken && selectedDay != null) {
        final now = DateTime.now();
        final DateTime todayOnly = DateTime(now.year, now.month, now.day);
        final DateTime selectedOnly = DateTime(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
        );
        final bool isPastDay = selectedOnly.isBefore(todayOnly);
        bool overdueToday = false;
        if (selectedOnly == todayOnly) {
          final parts = medication.time.split(':');
          final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
          final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          overdueToday = hh < now.hour || (hh == now.hour && mm <= now.minute);
        }
        isMissed = isPastDay || overdueToday;
      }
    } catch (_) {}

    final BoxDecoration deco = BoxDecoration(
      color: isTaken
          ? const Color(0xFFEAF2FF)
          : (isMissed ? const Color(0xFFFFE8EA) : const Color(0xFFFCFCFC)),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isTaken
            ? primaryBlue
            : (isMissed ? const Color(0xFFED9793) : const Color(0xFFDBDBDB)),
        width: 1.5,
      ),
      boxShadow: isTaken || isMissed
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
                  CustomChip(
                    text: '알람 ${medication.time}',
                    fg: Colors.black87,
                    bg: Colors.white,
                  )
                else
                  CustomChip(
                    text: formatKorTime(medication.time),
                    fg: isMissed ? dangerRed : Colors.black54,
                    bg: Colors.white,
                  ),
                if (isTaken)
                  CustomChip(
                    text:
                        '복용 완료${medication.takenAt != null ? ' ${formatHHmmKST(medication.takenAt!)}' : ''}',
                    fg: const Color(0xFF0034C4),
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
                else if (isMissed)
                  CustomChip(
                    text: '미복용',
                    fg: dangerRed,
                    bg: Colors.white,
                    icon: Icons.error_outline,
                  )
                else
                  CustomChip(
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
                      : (isMissed
                            ? SvgPicture.asset(
                                'assets/images/alarmList_late.svg',
                                width: 45,
                                height: 45,
                              )
                            : SvgPicture.asset(
                                'assets/images/alarmList_deactive.svg',
                                width: 45,
                                height: 45,
                              )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
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
}
