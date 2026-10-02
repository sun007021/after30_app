import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/utils/responsive.dart';

/// 알람 카드 위젯
class AlarmCard extends StatelessWidget {
  final MedicineAlarm alarm;
  final void Function() onToggle;
  final void Function() onEdit;
  final void Function() onDelete;

  /// iOS 전용: 스와이프로 삭제할 때 호출(확인은 [confirmSwipeDelete]에서 받은
  /// 뒤). Android는 팝업 메뉴의 [onDelete]를 그대로 쓴다.
  final void Function()? onSwipeDelete;
  final Future<bool> Function()? confirmSwipeDelete;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onSwipeDelete,
    this.confirmSwipeDelete,
  });

  String _formatTimeHHmm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  String _formatDays(List<String> days) {
    const order = ['월', '화', '수', '목', '금', '토', '일'];
    final set = days.toSet();
    final sorted = order.where(set.contains).toList();
    return sorted.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  // ---------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------

  Widget _cupertinoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: alarm.isActive ? Colors.white : AppColors.groupedBackground,
        borderRadius: BorderRadius.circular(AppRadius.capsule),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: alarm.isActive ? AppColors.label : AppColors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        color: alarm.isActive ? AppColors.primaryTint : AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  alarm.isActive
                      ? 'assets/images/alarmList_active.svg'
                      : 'assets/images/alarmList_deactive.svg',
                  width: 44,
                  height: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alarm.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title.copyWith(
                      color: alarm.isActive
                          ? AppColors.label
                          : AppColors.secondaryLabel,
                    ),
                  ),
                ),
                AppSwitch(value: alarm.isActive, onChanged: (_) => onToggle()),
              ],
            ),
            const SizedBox(height: 10),
            // 가로 스크롤 대신 줄바꿈 칩으로 둬서 좌우 스와이프 삭제와
            // 제스처가 겹치지 않게 한다.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _cupertinoChip(alarm.everyDay ? '매일' : _formatDays(alarm.days)),
                ...alarm.times.map((t) => _cupertinoChip(_formatTimeHHmm(t))),
              ],
            ),
            if (alarm.nfcEnabled) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.nfc, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'NFC 연동됨',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: onSwipeDelete == null
            ? content
            : AppSwipeActions(
                itemKey: ValueKey('alarmSwipe_${alarm.id}'),
                confirmDismiss: confirmSwipeDelete,
                onDelete: onSwipeDelete!,
                child: content,
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Android(기존 외형 그대로)
  // ---------------------------------------------------------------------

  Widget _buildMaterial(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: Responsive.responsiveValue(context, 8),
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 16),
        ),
        side: BorderSide(
          color: alarm.isActive
              ? const Color(0xFF235DFF)
              : Colors.grey.shade400,
        ),
      ),
      color: alarm.isActive ? const Color(0xFFEBF0FF) : Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.responsiveValue(context, 20),
          Responsive.responsiveValue(context, 3),
          Responsive.responsiveValue(context, 8),
          Responsive.responsiveValue(context, 20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top chips: days + times
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildChip(alarm.everyDay ? '매일' : _formatDays(alarm.days)),
                SizedBox(width: Responsive.responsiveWidth(context, 6)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...alarm.times.map(
                          (t) => Padding(
                            padding: EdgeInsets.only(
                              left: Responsive.responsiveValue(context, 6),
                            ),
                            child: _buildChip(_formatTimeHHmm(t)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  iconSize: Responsive.responsiveIconSize(context, 25),
                  icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('알람 수정')),
                    PopupMenuItem(value: 'delete', child: Text('알람 삭제')),
                  ],
                ),
              ],
            ),

            // Bottom: name + switch (align text with chip inner padding)
            Padding(
              padding: EdgeInsets.only(
                left: Responsive.responsiveValue(context, 0),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    alarm.isActive
                        ? 'assets/images/alarmList_active.svg'
                        : 'assets/images/alarmList_deactive.svg',
                    width: Responsive.responsiveIconSize(context, 50),
                    height: Responsive.responsiveIconSize(context, 50),
                  ),
                  SizedBox(width: Responsive.responsiveWidth(context, 8)),
                  Text(
                    alarm.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.responsiveFontSize(context, 16),
                    ),
                  ),
                  const Spacer(),
                  Transform.translate(
                    offset: const Offset(0, 15),
                    child: Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: alarm.isActive,
                        onChanged: (_) => onToggle(),
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF235DFF),
                        inactiveThumbColor: Colors.grey[400],
                        inactiveTrackColor: Colors.grey[300],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (alarm.nfcEnabled) ...[
              SizedBox(height: Responsive.responsiveHeight(context, 4)),
              Row(
                children: [
                  Icon(
                    Icons.nfc,
                    size: Responsive.responsiveIconSize(context, 16),
                    color: Colors.blue,
                  ),
                  SizedBox(width: Responsive.responsiveWidth(context, 4)),
                  Text(
                    'NFC 연동됨',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 12),
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
