import 'package:flutter/material.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/ui/widgets/medication_sheet_header.dart';
import 'package:after30/features/calendar/ui/widgets/medication_tile.dart';
import 'package:after30/features/calendar/ui/widgets/pinned_header_delegate.dart';
import 'package:after30/features/calendar/ui/widgets/week_strip.dart';
import 'package:after30/utils/responsive.dart';

class MedicationRecordSheetContent extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime? selectedDay;
  final int total;
  final int done;
  final Map<DateTime, int> totalByDay;
  final Map<DateTime, int> doneByDay;
  final List<Medication> medications;
  final bool isLoading;
  final String? title;
  final ValueChanged<DateTime> onDaySelected;
  final String emptyMessage;

  const MedicationRecordSheetContent({
    super.key,
    required this.scrollController,
    required this.selectedDay,
    required this.total,
    required this.done,
    required this.totalByDay,
    required this.doneByDay,
    required this.medications,
    this.isLoading = false,
    this.title,
    required this.onDaySelected,
    this.emptyMessage = '선택한 날짜에 기록이 없습니다',
  });

  double _pinnedHeaderHeight(BuildContext context) {
    final base = Responsive.responsiveValue(context, 70);
    if (title == null || title!.trim().isEmpty) return base;
    // 제목 줄 + 여백이 추가되는 만큼 높이 확보
    return base + Responsive.responsiveValue(context, 36);
  }

  double _weekStripHeaderHeight(BuildContext context) {
    // 요일 라벨 + 날짜 원 + 하단 여백
    return Responsive.responsiveValue(context, 88);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: _pinnedHeaderHeight(context),
              child: ClipRect(
                child: Container(
                  height: _pinnedHeaderHeight(context),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: Responsive.responsiveHeight(context, 8)),
                      Container(
                        width: Responsive.responsiveValue(context, 64),
                        height: Responsive.responsiveValue(context, 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(
                            Responsive.responsiveValue(context, 3),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.responsiveHeight(context, 12)),
                      if (title != null && title!.trim().isNotEmpty) ...[
                        Text(
                          title!.trim(),
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(context, 17),
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: Responsive.responsiveHeight(context, 8)),
                      ],
                      MedicationSheetHeader(
                        selectedDay: selectedDay,
                        total: total,
                        done: done,
                      ),
                      if (title == null || title!.trim().isEmpty)
                        SizedBox(height: Responsive.responsiveHeight(context, 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedHeaderDelegate(
              height: _weekStripHeaderHeight(context),
              child: Container(
                height: _weekStripHeaderHeight(context),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: Responsive.responsivePadding(context, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: WeekStrip(
                          selectedDay: selectedDay,
                          onDaySelected: onDaySelected,
                          totalByDay: totalByDay,
                          doneByDay: doneByDay,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.responsiveHeight(context, 12)),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (medications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: Responsive.responsiveFontSize(context, 14),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: Responsive.responsivePadding(context, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return MedicationTile(
                    medication: medications[index],
                    selectedDay: selectedDay,
                  );
                }, childCount: medications.length),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: Responsive.responsiveHeight(context, 20),
            ),
          ),
        ],
      ),
    );
  }
}
