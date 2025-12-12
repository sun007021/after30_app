import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';

/// 홈 화면의 약물 복용 타일 위젯
class MedicationDoseTile extends StatelessWidget {
  final Medication medication;
  final DateTime selectedDate;
  final String doseKey;
  final Future<void> Function(String) onMarkCompleted;
  final Future<void> Function(String) onMarkUncompleted;

  const MedicationDoseTile({
    super.key,
    required this.medication,
    required this.selectedDate,
    required this.doseKey,
    required this.onMarkCompleted,
    required this.onMarkUncompleted,
  });

  bool _calculateIsOverdue(
    DateTime selectedDate,
    String timeStr,
    bool isCompleted,
  ) {
    if (isCompleted) return false;
    try {
      final now = DateTime.now();
      final isSameDay =
          selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day;
      if (!isSameDay) return false;

      final parts = timeStr.split(':');
      final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return hh < now.hour || (hh == now.hour && mm <= now.minute);
    } catch (_) {
      return false;
    }
  }

  bool _calculateIsMissed(
    DateTime selectedDate,
    bool isCompleted,
    bool isOverdue,
  ) {
    if (isCompleted) return false;
    final nowDate = DateTime.now();
    final todayOnly = DateTime(nowDate.year, nowDate.month, nowDate.day);
    final selectedOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isPastDay = selectedOnly.isBefore(todayOnly);
    return isPastDay || isOverdue;
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    const lightBlueBg = Color(0xFFE6F0FF);
    const lightGreyBg = Color(0xFFFCFCFC);
    const greyBorder = Color(0xFFD9D9D9);
    const dangerRed = Color(0xFFE50000);
    const lightRedBg = Color(0xFFFFE8EA);
    const lightRedBorder = Color(0xFFED9793);

    final isCompleted = medication.status == 'taken';
    final timeLabel = formatKoreanTime(medication.time);
    final isOverdue = _calculateIsOverdue(
      selectedDate,
      medication.time,
      isCompleted,
    );
    final isMissed = _calculateIsMissed(selectedDate, isCompleted, isOverdue);

    final nowDate = DateTime.now();
    final isToday =
        selectedDate.year == nowDate.year &&
        selectedDate.month == nowDate.month &&
        selectedDate.day == nowDate.day;

    return Center(
      child: SizedBox(
        width: 320,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isCompleted
                ? lightBlueBg
                : (isMissed ? lightRedBg : lightGreyBg),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? primaryBlue
                  : (isMissed ? lightRedBorder : greyBorder),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCompleted)
                      SvgPicture.asset(
                        'assets/images/check.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          primaryBlue,
                          BlendMode.srcIn,
                        ),
                      )
                    else
                      Icon(
                        isMissed ? Icons.error_outline : Icons.access_time,
                        color: isMissed ? dangerRed : Colors.black38,
                        size: 25,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      isCompleted ? '복용 완료' : (isMissed ? '미복용' : '복약 예정'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? const Color(0xFF0034C4)
                            : (isMissed ? dangerRed : Colors.black45),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCompleted && medication.takenAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          formatHHmm(medication.takenAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0034C4),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (isCompleted || isMissed)
                      Builder(
                        builder: (buttonCtx) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (TapDownDetails details) async {
                            try {
                              final RenderBox buttonBox =
                                  buttonCtx.findRenderObject() as RenderBox;
                              final RenderBox overlay =
                                  Overlay.of(
                                        buttonCtx,
                                      ).context.findRenderObject()
                                      as RenderBox;
                              final Offset topLeft = buttonBox.localToGlobal(
                                Offset.zero,
                                ancestor: overlay,
                              );
                              final Offset bottomRight = buttonBox
                                  .localToGlobal(
                                    buttonBox.size.bottomRight(Offset.zero),
                                    ancestor: overlay,
                                  );
                              final position = RelativeRect.fromLTRB(
                                topLeft.dx,
                                topLeft.dy,
                                overlay.size.width - bottomRight.dx,
                                overlay.size.height - bottomRight.dy,
                              );
                              final List<PopupMenuEntry<String>> items =
                                  isCompleted
                                  ? const [
                                      PopupMenuItem<String>(
                                        value: 'undo',
                                        child: Text('복약 미완료'),
                                      ),
                                    ]
                                  : const [
                                      PopupMenuItem<String>(
                                        value: 'complete',
                                        child: Text('복용 완료'),
                                      ),
                                    ];
                              final selected = await showMenu<String>(
                                context: buttonCtx,
                                position: position,
                                color: Colors.white,
                                items: items,
                              );
                              if (selected == 'complete') {
                                await onMarkCompleted(doseKey);
                              } else if (selected == 'undo') {
                                await onMarkUncompleted(doseKey);
                              }
                            } catch (_) {}
                          },
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.more_vert,
                              size: 24,
                              color: Colors.black26,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted && isToday && !isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ElevatedButton(
                          onPressed: () => onMarkCompleted(doseKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            minimumSize: const Size(0, 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '복용 완료',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
