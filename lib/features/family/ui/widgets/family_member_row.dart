import 'package:flutter/material.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/utils/responsive.dart';

class FamilyMemberRow extends StatelessWidget {
  static const int columnsPerRow = 3;

  final List<GroupMember> members;
  final List<FamilyInvitation> pendingInvitations;
  final Map<int, MemberMedicationSummary> summariesByUserId;
  final int? selectedUserId;
  final ValueChanged<int> onMemberSelected;
  final VoidCallback onAddMember;

  const FamilyMemberRow({
    super.key,
    required this.members,
    this.pendingInvitations = const [],
    required this.summariesByUserId,
    required this.selectedUserId,
    required this.onMemberSelected,
    required this.onAddMember,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 15, 0, 15, 15),
      child: Container(
        width: double.infinity,
        padding: Responsive.responsivePaddingLTRB(context, 16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFA4A4A4)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / columnsPerRow;
            final items = <Widget>[
              ...members.map((member) {
                final summary = summariesByUserId[member.userId];
                final isSelected = selectedUserId == member.userId;
                return _MemberAvatar(
                  name: member.userName ?? '멤버',
                  progress: summary?.progress ?? 0,
                  isSelected: isSelected,
                  onTap: () => onMemberSelected(member.userId),
                );
              }),
              ...pendingInvitations.map(
                (invitation) => _PendingInviteAvatar(
                  name: invitation.displayName,
                ),
              ),
              _AddMemberAvatar(onTap: onAddMember),
            ];

            return Wrap(
              spacing: 0,
              runSpacing: Responsive.responsiveHeight(context, 16),
              children: items
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: item,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String name;
  final double progress;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberAvatar({
    required this.name,
    required this.progress,
    required this.isSelected,
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
    const primaryBlue = Color(0xFF235DFF);
    final displayName = name.trim().isEmpty ? '멤버' : name.trim();
    final initial = displayName.substring(0, 1);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: Responsive.responsiveValue(context, 76),
            height: Responsive.responsiveValue(context, 76),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (progress > 0)
                  SizedBox(
                    width: Responsive.responsiveValue(context, 86),
                    height: Responsive.responsiveValue(context, 86),
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor: const Color(0xFFEDEFF2),
                      color: primaryBlue,
                    ),
                  ),
                Container(
                  width: Responsive.responsiveValue(context, 68),
                  height: Responsive.responsiveValue(context, 68),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _avatarColor(displayName),
                    border: isSelected
                        ? Border.all(color: primaryBlue, width: 2.5)
                        : null,
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
    );
  }
}

/// 초대 수락 대기 중인 사용자 아바타
class _PendingInviteAvatar extends StatelessWidget {
  final String name;

  const _PendingInviteAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? '초대중' : name.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: Responsive.responsiveValue(context, 76),
          height: Responsive.responsiveValue(context, 76),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: Responsive.responsiveValue(context, 68),
                height: Responsive.responsiveValue(context, 68),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD6DDEA),
                  border: Border.all(
                    color: const Color(0xFF9AA6BF),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_outline,
                  color: const Color(0xFF7A8699),
                  size: Responsive.responsiveIconSize(context, 30),
                ),
              ),
              Positioned(
                right: -2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7280),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '대기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.responsiveFontSize(context, 9),
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
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
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _AddMemberAvatar extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMemberAvatar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: Responsive.responsiveValue(context, 76),
            height: Responsive.responsiveValue(context, 76),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: Responsive.responsiveValue(context, 70),
                  height: Responsive.responsiveValue(context, 70),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA7BEFF),
                    border: Border.all(color: primaryBlue),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: primaryBlue,
                    size: Responsive.responsiveIconSize(context, 30),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 6)),
          Text(
            '초대',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 12),
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
