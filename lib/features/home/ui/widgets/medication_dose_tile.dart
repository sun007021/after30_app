import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:after30/utils/responsive.dart';

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

  Future<void> _handleMarkCompleted(BuildContext context) async {
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: '오늘도 해내셨네요!',
      message: '꾸준히 약을 챙겨 먹는 모습이 멋져요. 오늘의 복약 완료 도장을 찍어 드릴게요.',
      cancelLabel: '닫기',
      confirmLabel: '확인',
    );
    if (!confirmed) return;
    await onMarkCompleted(doseKey);
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

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: Responsive.responsiveValue(context, 6),
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? lightBlueBg
            : (isMissed ? lightRedBg : lightGreyBg),
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 16),
        ),
        border: Border.all(
          color: isCompleted
              ? primaryBlue
              : (isMissed ? lightRedBorder : greyBorder),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: Responsive.responsivePaddingLTRB(context, 20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isCompleted)
                  SvgPicture.asset(
                    'assets/images/check.svg',
                    width: Responsive.responsiveIconSize(context, 20),
                    height: Responsive.responsiveIconSize(context, 20),
                    colorFilter: const ColorFilter.mode(
                      primaryBlue,
                      BlendMode.srcIn,
                    ),
                  )
                else
                  Icon(
                    isMissed ? Icons.error_outline : Icons.access_time,
                    color: isMissed ? dangerRed : Colors.black38,
                    size: Responsive.responsiveIconSize(context, 25),
                  ),
                SizedBox(width: Responsive.responsiveWidth(context, 6)),
                Text(
                  isCompleted ? '복용 완료' : (isMissed ? '미복용' : '복약 예정'),
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: isCompleted
                        ? const Color(0xFF0034C4)
                        : (isMissed ? dangerRed : Colors.black45),
                  ),
                ),
                SizedBox(width: Responsive.responsiveWidth(context, 8)),
                if (isCompleted && medication.takenAt != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.responsiveValue(context, 8),
                      vertical: Responsive.responsiveValue(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        Responsive.responsiveValue(context, 12),
                      ),
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
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0034C4),
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
                              Overlay.of(buttonCtx).context.findRenderObject()
                                  as RenderBox;
                          final Offset topLeft = buttonBox.localToGlobal(
                            Offset.zero,
                            ancestor: overlay,
                          );
                          final Offset bottomRight = buttonBox.localToGlobal(
                            buttonBox.size.bottomRight(Offset.zero),
                            ancestor: overlay,
                          );
                          final position = RelativeRect.fromLTRB(
                            topLeft.dx,
                            topLeft.dy,
                            overlay.size.width - bottomRight.dx,
                            overlay.size.height - bottomRight.dy,
                          );
                          final List<PopupMenuEntry<String>> items = isCompleted
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
                            await _handleMarkCompleted(buttonCtx);
                          } else if (selected == 'undo') {
                            await onMarkUncompleted(doseKey);
                          }
                        } catch (_) {}
                      },
                      child: SizedBox(
                        width: Responsive.responsiveIconSize(context, 24),
                        height: Responsive.responsiveIconSize(context, 24),
                        child: Icon(
                          Icons.more_vert,
                          size: Responsive.responsiveIconSize(context, 24),
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: Responsive.responsiveHeight(context, 2)),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.responsiveValue(context, 0),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(
                              context,
                              12,
                            ),
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCompleted && isToday && !isOverdue)
                  Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.responsiveValue(context, 8),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _handleMarkCompleted(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.responsiveValue(context, 12),
                          vertical: Responsive.responsiveValue(context, 5),
                        ),
                        minimumSize: Size(
                          0,
                          Responsive.responsiveValue(context, 20),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.responsiveValue(context, 10),
                          ),
                        ),
                      ),
                      child: Text(
                        '복용 완료',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 12),
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
    );
  }
}
