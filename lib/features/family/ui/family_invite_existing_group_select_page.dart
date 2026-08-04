import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/utils/responsive.dart';

class FamilyInviteExistingGroupSelectPage extends StatefulWidget {
  const FamilyInviteExistingGroupSelectPage({super.key});

  @override
  State<FamilyInviteExistingGroupSelectPage> createState() =>
      _FamilyInviteExistingGroupSelectPageState();
}

class _FamilyInviteExistingGroupSelectPageState
    extends State<FamilyInviteExistingGroupSelectPage> {
  final FamilyService _familyService = FamilyService();

  List<FamilyGroupDetail> _groups = [];
  int? _pressedGroupId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _familyService.getUserGroupsWithMembers();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '그룹 목록을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _onGroupTap(FamilyGroupDetail groupDetail) async {
    setState(() => _pressedGroupId = groupDetail.group.id);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _openInvitePage(groupDetail);
    if (!mounted) return;
    setState(() => _pressedGroupId = null);
  }

  void _openInvitePage(FamilyGroupDetail groupDetail) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyInviteExistingGroupInvitePage(
          groupId: groupDetail.group.id,
          groupName: groupDetail.group.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: Responsive.responsivePadding(context, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: const Color(0xFF111111),
                        size: Responsive.responsiveIconSize(context, 18),
                      ),
                    ),
                  ),
                  const StepHeader(
                    currentStep: 2,
                    step1Label: '',
                    step2Label: '',
                    step3Label: '',
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 12)),
                  Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      28,
                      0,
                      0,
                      0,
                    ),
                    child: Text(
                      '2. 기존 그룹 선택',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 20),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 24)),
                  Expanded(child: _buildBody(context)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 14),
                color: const Color(0xFF737373),
              ),
            ),
            SizedBox(height: Responsive.responsiveHeight(context, 12)),
            TextButton(onPressed: _loadGroups, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Text(
          '참여 중인 가족 그룹이 없습니다.',
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 14),
            color: const Color(0xFF737373),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: Responsive.responsivePaddingLTRB(context, 28, 0, 28, 16),
      itemCount: _groups.length,
      separatorBuilder: (_, __) =>
          SizedBox(height: Responsive.responsiveHeight(context, 30)),
      itemBuilder: (context, index) {
        final groupDetail = _groups[index];
        return _GroupSelectCard(
          groupDetail: groupDetail,
          isSelected: _pressedGroupId == groupDetail.group.id,
          onTap: () => _onGroupTap(groupDetail),
        );
      },
    );
  }
}

class _GroupSelectCard extends StatefulWidget {
  const _GroupSelectCard({
    required this.groupDetail,
    required this.isSelected,
    required this.onTap,
  });

  final FamilyGroupDetail groupDetail;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_GroupSelectCard> createState() => _GroupSelectCardState();
}

class _GroupSelectCardState extends State<_GroupSelectCard> {
  bool _isPressed = false;

  bool get _isActive => widget.isSelected || _isPressed;

  @override
  Widget build(BuildContext context) {
    final chipBackground =
        _isActive ? const Color(0xFFECF4FF) : const Color(0xFFEAEAEA);
    final chipTextColor =
        _isActive ? const Color(0xFF4595FF) : const Color(0xFF737373);
    final extraCount = _remainingAvatarCount(widget.groupDetail.members);
    final chipGap = Responsive.responsiveWidth(context, 16);
    final cardPadding = Responsive.responsivePaddingLTRB(context, 24, 16, 16, 16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: const Color(0xFFECF4FF).withValues(alpha: 0.4),
        highlightColor: const Color(0xFFECF4FF).withValues(alpha: 0.2),
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF98C4FF)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _InfoChip(
                      label: widget.groupDetail.memberCountLabel,
                      backgroundColor: chipBackground,
                      textColor: chipTextColor,
                      width: Responsive.responsiveWidth(context, 60),
                      fontSize: Responsive.responsiveFontSize(context, 13),
                    ),
                    SizedBox(width: chipGap),
                    Expanded(
                      child: _InfoChip(
                        label: widget.groupDetail.memberNamesLabel,
                        backgroundColor: chipBackground,
                        textColor: chipTextColor,
                        fontSize: Responsive.responsiveFontSize(context, 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 14)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.groupDetail.group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                20,
                              ),
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          SizedBox(
                            height: Responsive.responsiveHeight(context, 4),
                          ),
                          Text(
                            widget.groupDetail.representativeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                9,
                              ),
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF484848),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: Responsive.responsiveWidth(context, 8)),
                    _MemberAvatarStack(
                      members: widget.groupDetail.members,
                      extraCount: extraCount,
                      isSelected: _isActive,
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

  int _remainingAvatarCount(List<GroupMember> members) {
    const visibleCount = 3;
    final total = members.length;
    if (total <= visibleCount) return 0;
    return total - visibleCount;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    this.width,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: Responsive.responsiveValue(context, 22),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.responsiveWidth(context, 10),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  const _MemberAvatarStack({
    required this.members,
    required this.extraCount,
    required this.isSelected,
  });

  final List<GroupMember> members;
  final int extraCount;
  final bool isSelected;

  static const _avatarColors = [
    Color(0xFFD9D9D9),
    Color(0xFFBDBDBD),
    Color(0xFFA0A0A0),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleMembers = members.take(3).toList();
    final avatarSize = Responsive.responsiveValue(context, 40);
    final overlap = Responsive.responsiveValue(context, 18);
    final stackWidth = visibleMembers.isEmpty
        ? 0.0
        : avatarSize + (visibleMembers.length - 1) * overlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visibleMembers.isNotEmpty)
          SizedBox(
            width: stackWidth,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < visibleMembers.length; i++)
                  Positioned(
                    left: i * overlap,
                    child: _MemberAvatar(
                      member: visibleMembers[i],
                      size: avatarSize,
                      color: _avatarColors[i % _avatarColors.length],
                    ),
                  ),
              ],
            ),
          ),
        if (extraCount > 0) ...[
          SizedBox(width: Responsive.responsiveWidth(context, 4)),
          Text(
            '+$extraCount',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 12),
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF4595FF)
                  : const Color(0xFF696969),
            ),
          ),
        ],
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.member,
    required this.size,
    required this.color,
  });

  final GroupMember member;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = member.userName?.trim();
    final initial = (name != null && name.isNotEmpty) ? name[0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 14),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
