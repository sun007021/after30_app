import 'package:flutter/material.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/utils/responsive.dart';

/// 홈 상단 — 가족 멤버 복용 현황 원형 게이지 + 멤버 추가
class HomeFamilyGaugeRow extends StatelessWidget {
  final List<MemberMedicationSummary> members;
  final ValueChanged<MemberMedicationSummary> onMemberTap;
  final VoidCallback onAddTap;

  const HomeFamilyGaugeRow({
    super.key,
    required this.members,
    required this.onMemberTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPad = Responsive.responsiveValue(context, 16);
    final gap = Responsive.responsiveValue(context, 16);
    final itemCount = members.length + 1; // + 추가 버튼

    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.responsiveHeight(context, 4),
        bottom: Responsive.responsiveHeight(context, 12),
      ),
      child: SizedBox(
        height: Responsive.responsiveValue(context, 110),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(width: gap),
          itemBuilder: (context, index) {
            if (index == members.length) {
              return _HomeAddMemberButton(onTap: onAddTap);
            }
            final member = members[index];
            return _HomeMemberGauge(
              name: member.userName ?? '멤버',
              progress: member.progress,
              onTap: () => onMemberTap(member),
            );
          },
        ),
      ),
    );
  }
}

class _HomeMemberGauge extends StatelessWidget {
  static const Color _primaryBlue = Color(0xFF235DFF);
  static const Color _trackColor = Color(0xFFE8EDF8);

  final String name;
  final double progress;
  final VoidCallback onTap;

  const _HomeMemberGauge({
    required this.name,
    required this.progress,
    required this.onTap,
  });

  Color _avatarColor(String seed) {
    const colors = [
      Color(0xFF6B8CFF),
      Color(0xFF8EC5FF),
      Color(0xFFFFB86B),
      Color(0xFF9ADBB0),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? '멤버' : name.trim();
    final initial = displayName.substring(0, 1);
    final outerSize = Responsive.responsiveValue(context, 82);
    final avatarSize = Responsive.responsiveValue(context, 68);
    final clamped = progress.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: outerSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: outerSize,
                    height: outerSize,
                    child: CircularProgressIndicator(
                      value: clamped,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: _trackColor,
                      color: _primaryBlue,
                    ),
                  ),
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _avatarColor(displayName),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.responsiveFontSize(context, 24),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 6)),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 12),
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAddMemberButton extends StatelessWidget {
  static const Color _primaryBlue = Color(0xFF235DFF);

  final VoidCallback onTap;

  const _HomeAddMemberButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outerSize = Responsive.responsiveValue(context, 82);
    final avatarSize = Responsive.responsiveValue(context, 68);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: outerSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: outerSize,
              height: outerSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFA7BEFF),
                      border: Border.all(color: _primaryBlue),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: _primaryBlue,
                      size: Responsive.responsiveIconSize(context, 30),
                    ),
                  ),
                  Positioned(
                    right: Responsive.responsiveValue(context, 2),
                    top: Responsive.responsiveValue(context, 2),
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 6)),
            // 이름 영역 높이 맞춤 (피그마에 라벨 없음)
            SizedBox(
              height: Responsive.responsiveFontSize(context, 12) * 1.2,
            ),
          ],
        ),
      ),
    );
  }
}
