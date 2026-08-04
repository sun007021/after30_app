import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/auth/current_user_resolver.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/utils/responsive.dart';

class FamilyGroupManagePage extends StatefulWidget {
  final int groupId;
  final String groupName;

  const FamilyGroupManagePage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<FamilyGroupManagePage> createState() => _FamilyGroupManagePageState();
}

class _FamilyGroupManagePageState extends State<FamilyGroupManagePage> {
  final FamilyService _familyService = FamilyService();

  bool _isLoading = true;
  bool _isProcessing = false;
  List<GroupMember> _members = [];
  int? _currentUserId;
  late String _groupName;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storedUserId = await UserStore.getCurrentUserId();
      final members = await _familyService.getGroupMembers(widget.groupId);
      final currentUserId = await CurrentUserResolver.resolveUserId(
        members: members,
      );
      if (!mounted) return;
      setState(() {
        _currentUserId = currentUserId ?? int.tryParse(storedUserId ?? '');
        _members = members;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '그룹 정보를 불러오지 못했습니다.',
      );
    }
  }

  bool get _isOwner {
    final userId = _currentUserId;
    if (userId == null) return false;
    return _members.any((m) => m.userId == userId && m.isOwner);
  }

  bool get _canLeaveGroup {
    if (!_isOwner) return true;
    return _members.length <= 1;
  }

  Future<void> _openInvite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyInviteExistingGroupInvitePage(
          groupId: widget.groupId,
          groupName: _groupName,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _editGroupName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _GroupNameEditDialog(initialName: _groupName);
      },
    );

    final trimmed = newName?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == _groupName) return;

    setState(() => _isProcessing = true);
    try {
      final group = await _familyService.updateGroupName(
        groupId: widget.groupId,
        name: trimmed,
      );
      if (!mounted) return;
      setState(() => _groupName = group.name);
    } catch (_) {
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '그룹 이름 수정에 실패했습니다.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _transferOwnership(GroupMember member) async {
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: '가족장 위임',
      message: '${member.userName ?? '가족'}님에게 가족장을 위임하시겠습니까?',
      cancelLabel: '취소',
      confirmLabel: '위임',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _familyService.transferOwnership(
        groupId: widget.groupId,
        newOwnerUserId: member.userId,
      );
      await _loadData();
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '가족장을 위임했습니다.',
      );
    } catch (_) {
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '가족장 위임에 실패했습니다.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: '멤버 제거',
      message: '${member.userName ?? '가족'}님을 그룹에서 제거하시겠습니까?',
      cancelLabel: '취소',
      confirmLabel: '제거',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _familyService.removeMember(
        groupId: widget.groupId,
        targetUserId: member.userId,
      );
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '멤버 제거에 실패했습니다.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _leaveGroup() async {
    if (!_canLeaveGroup) {
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '탈퇴 불가',
        message: '가족장은 다른 멤버에게 가족장을 위임한 후 탈퇴할 수 있습니다.',
      );
      return;
    }

    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: '가족 그룹 탈퇴',
      message: '정말 이 가족 그룹에서 탈퇴하시겠습니까?',
      cancelLabel: '취소',
      confirmLabel: '탈퇴',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _familyService.leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const FamilyPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: '그룹 탈퇴에 실패했습니다.',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showMemberMenu(BuildContext context, GroupMember member) {
    final RenderBox button =
        context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 60,
        position.dy + button.size.height,
        position.dx,
        position.dy,
      ),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFBCBCBC)),
      ),
      elevation: 4,
      items: [
        if (_isOwner && !member.isOwner)
          const PopupMenuItem(
            value: 'transfer',
            height: 29,
            child: Text(
              '가족장 위임',
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
        if (_isOwner && member.userId != _currentUserId)
          const PopupMenuItem(
            value: 'remove',
            height: 29,
            child: Text(
              '멤버 제거',
              style: TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
      ],
    ).then((value) {
      if (value == 'transfer') {
        _transferOwnership(member);
      } else if (value == 'remove') {
        _removeMember(member);
      }
    });
  }

  Color _avatarColor(String seed) {
    const colors = [
      Color(0xFF6B8CFF),
      Color(0xFF8EC5FF),
      Color(0xFFFFB86B),
      Color(0xFF9ADBB0),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }

  Widget _buildAvatar(String name, {double size = 31}) {
    final displayName = name.trim().isEmpty ? '멤버' : name.trim();
    final initial = displayName.substring(0, 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColor(displayName),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderAvatars() {
    final displayMembers = _members.take(2).toList();
    if (displayMembers.isEmpty) {
      return const SizedBox(height: 55);
    }
    if (displayMembers.length == 1) {
      return _buildAvatar(displayMembers.first.userName ?? '멤버', size: 55);
    }
    return SizedBox(
      width: 90,
      height: 55,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: _buildAvatar(displayMembers[0].userName ?? '멤버', size: 55),
          ),
          Positioned(
            left: 28,
            child: _buildAvatar(displayMembers[1].userName ?? '멤버', size: 55),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      20,
                      8,
                      20,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: const Color(0xFF111111),
                          size: Responsive.responsiveIconSize(context, 18),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 8)),
                  Center(child: _buildHeaderAvatars()),
                  SizedBox(height: Responsive.responsiveHeight(context, 12)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _groupName,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (_isOwner) ...[
                          SizedBox(
                            width: Responsive.responsiveValue(context, 6),
                          ),
                          GestureDetector(
                            onTap: _isProcessing ? null : _editGroupName,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: SvgPicture.asset(
                                'assets/images/mypage_edit.svg',
                                width: Responsive.responsiveIconSize(
                                  context,
                                  16,
                                ),
                                height: Responsive.responsiveIconSize(
                                  context,
                                  16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 24)),
                  Expanded(
                    child: Padding(
                      padding: Responsive.responsivePaddingLTRB(
                        context,
                        23,
                        0,
                        23,
                        0,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: Responsive.responsivePaddingLTRB(
                                context,
                                22,
                                22,
                                22,
                                20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '그룹 인원  ${_members.length}',
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.responsiveFontSize(
                                        context,
                                        15,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(
                                    height:
                                        Responsive.responsiveHeight(context, 24),
                                  ),
                                  _AddMemberRow(onTap: _openInvite),
                                  SizedBox(
                                    height:
                                        Responsive.responsiveHeight(context, 16),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _members.length,
                                      separatorBuilder: (_, __) => SizedBox(
                                        height: Responsive.responsiveHeight(
                                          context,
                                          14,
                                        ),
                                      ),
                                      itemBuilder: (context, index) {
                                        final member = _members[index];
                                        final isSelf =
                                            member.userId == _currentUserId;
                                        final name =
                                            member.userName ?? '가족';
                                        final showMenu = _isOwner &&
                                            !isSelf &&
                                            !_isProcessing;

                                        return Row(
                                          children: [
                                            _buildAvatar(name, size: 40),
                                            if (isSelf) ...[
                                              SizedBox(
                                                width: Responsive.responsiveValue(
                                                  context,
                                                  8,
                                                ),
                                              ),
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFD9D9D9),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  '나',
                                                  style: TextStyle(
                                                    fontSize: Responsive
                                                        .responsiveFontSize(
                                                      context,
                                                      10,
                                                    ),
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black,
                                                    height: 1,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: Responsive.responsiveValue(
                                                  context,
                                                  6,
                                                ),
                                              ),
                                            ] else
                                              SizedBox(
                                                width: Responsive.responsiveValue(
                                                  context,
                                                  10,
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: Responsive
                                                      .responsiveFontSize(
                                                    context,
                                                    15,
                                                  ),
                                                  color: Colors.black,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (showMenu)
                                              Builder(
                                                builder: (menuContext) {
                                                  return GestureDetector(
                                                    onTap: () =>
                                                        _showMemberMenu(
                                                      menuContext,
                                                      member,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: List.generate(
                                                          3,
                                                          (_) => Container(
                                                            width: 4,
                                                            height: 4,
                                                            margin:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              vertical: 1.5,
                                                            ),
                                                            decoration:
                                                                const BoxDecoration(
                                                              color: Colors
                                                                  .black54,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: Responsive.responsiveHeight(context, 16),
                          ),
                          GestureDetector(
                            onTap: _isProcessing ? null : _leaveGroup,
                            child: Container(
                              width: double.infinity,
                              height: Responsive.responsiveHeight(context, 46),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '가족 그룹 탈퇴하기',
                                style: TextStyle(
                                  fontSize:
                                      Responsive.responsiveFontSize(
                                    context,
                                    12,
                                  ),
                                  color: _canLeaveGroup
                                      ? const Color(0xFFE00000)
                                      : const Color(0xFFB0B0B0),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: Responsive.responsiveHeight(context, 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }
}

class _AddMemberRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMemberRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA7BEFF),
                    border: Border.all(color: primaryBlue),
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.responsiveValue(context, 10)),
          Text(
            '추가하기',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 15),
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupNameEditDialog extends StatefulWidget {
  final String initialName;

  const _GroupNameEditDialog({required this.initialName});

  @override
  State<_GroupNameEditDialog> createState() => _GroupNameEditDialogState();
}

class _GroupNameEditDialogState extends State<_GroupNameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Text(
        '그룹 이름 수정',
        style: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 16),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          hintText: '그룹 이름',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text(
            '저장',
            style: TextStyle(color: Color(0xFF235DFF)),
          ),
        ),
      ],
    );
  }
}
