import 'package:flutter/material.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';
import 'package:after30/features/calendar/ui/widgets/medication_record_sheet_content.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/models/family_group.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/family/ui/family_group_manage_page.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/features/family/ui/widgets/family_empty_state.dart';
import 'package:after30/features/family/ui/widgets/family_invitation_banner.dart';
import 'package:after30/features/family/ui/widgets/family_member_row.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:after30/utils/responsive.dart';

class FamilyPage extends StatefulWidget {
  final int? initialGroupId;

  const FamilyPage({super.key, this.initialGroupId});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final FamilyService _familyService = FamilyService();
  final MyProfileService _profileService = MyProfileService();

  bool _isLoading = true;
  int? _processingInvitationId;
  bool _isLoadingMedications = false;
  bool _hasCheckedPhoneRegistration = false;
  String? _errorMessage;

  List<FamilyGroup> _groups = [];
  FamilyGroup? _selectedGroup;
  List<GroupMember> _members = [];
  /// 멤버 프로필 게이지용 — 항상 오늘 날짜 기준
  FamilyDashboard? _todayDashboard;
  /// 바텀시트 복용 현황용 — 선택한 날짜 기준
  FamilyDashboard? _dashboard;
  /// 나에게 온 초대 (배너용)
  List<FamilyInvitation> _pendingInvitations = [];
  /// 현재 그룹에 보낸 초대 중 수락 대기 (멤버 행 pending 표시용)
  List<FamilyInvitation> _groupPendingInvitations = [];

  int? _selectedUserId;
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, int> _totalByDay = {};
  Map<DateTime, int> _doneByDay = {};
  List<Medication> _medications = [];

  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  final GlobalKey _memberRowKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _groupDropdownKey = GlobalKey();
  double? _minInitialSheetFraction;

  static const double _sheetTopGap = 15;

  @override
  void initState() {
    super.initState();
    _loadPageData();
    _checkMyPhoneRegistration();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateSheetFractions();
    });
  }

  Future<void> _checkMyPhoneRegistration() async {
    if (_hasCheckedPhoneRegistration) return;
    _hasCheckedPhoneRegistration = true;

    try {
      final profile = await _profileService.getMyProfile();
      if (!mounted || profile.hasPhoneNumber) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPhoneRegisterPopup();
      });
    } catch (_) {}
  }

  void _leaveFamilyPage() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _showPhoneRegisterPopup() async {
    await PhoneRegisterDialog.show(
      context: context,
      onCancel: _leaveFamilyPage,
      onGoToMyPage: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const MyPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _recalculateSheetFractions() {
    if (_groups.isEmpty) return;
    final memberCtx = _memberRowKey.currentContext;
    final stackCtx = _stackKey.currentContext;
    if (memberCtx == null || stackCtx == null) return;

    final memberBox = memberCtx.findRenderObject() as RenderBox?;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    if (memberBox == null || stackBox == null) return;

    final memberBottomGlobal = memberBox.localToGlobal(
      Offset(0, memberBox.size.height),
    );
    final stackTopGlobal = stackBox.localToGlobal(Offset.zero);
    final stackHeight = stackBox.size.height;
    final memberBottomInStack = memberBottomGlobal.dy - stackTopGlobal.dy;
    final sheetTopInStack = memberBottomInStack + _sheetTopGap;
    final sheetHeight = stackHeight - sheetTopInStack;

    if (sheetHeight <= 0 || stackHeight <= 0) return;

    final initialFraction = (sheetHeight / stackHeight).clamp(0.25, 0.95);
    if (!mounted) return;

    final previousFraction = _minInitialSheetFraction;
    setState(() => _minInitialSheetFraction = initialFraction);

    try {
      final current = _dragController.size;
      final wasAtMin =
          previousFraction == null ||
          current <= (previousFraction + 0.02);
      if (wasAtMin || current < initialFraction) {
        _dragController.jumpTo(initialFraction);
      }
    } catch (_) {}
  }

  DateTime _startOfWeekSun(DateTime date) {
    final only = DateTime(date.year, date.month, date.day);
    return only.subtract(Duration(days: only.weekday % 7));
  }

  Future<void> _loadPageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _familyService.getUserGroups(),
        _familyService.getMyInvitations(),
      ]);

      final groups = results[0] as List<FamilyGroup>;
      final invitations = results[1] as List<FamilyInvitation>;
      final pending = invitations.where((item) => item.isPending).toList();

      FamilyGroup? selected = _selectedGroup;
      if (groups.isEmpty) {
        selected = null;
      } else if (widget.initialGroupId != null &&
          groups.any((group) => group.id == widget.initialGroupId)) {
        selected = groups.firstWhere(
          (group) => group.id == widget.initialGroupId,
        );
      } else if (selected == null ||
          !groups.any((group) => group.id == selected!.id)) {
        selected = groups.first;
      } else {
        selected = groups.firstWhere((group) => group.id == selected!.id);
      }

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _pendingInvitations = pending;
        if (selected == null) {
          _groupPendingInvitations = [];
          _members = [];
        }
        _isLoading = false;
      });

      if (selected != null) {
        await _loadGroupData(selected.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _recalculateSheetFractions();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '가족 정보를 불러오지 못했습니다.';
      });
    }
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _loadGroupData(int groupId) async {
    try {
      final membersFuture = _familyService.getGroupMembers(groupId);
      final today = _todayDate;
      final selected = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final todayDashboardFuture = _familyService.getDashboard(
        groupId: groupId,
        targetDate: today,
      );
      final selectedDashboardFuture = _isSameDay(selected, today)
          ? todayDashboardFuture
          : _familyService.getDashboard(
              groupId: groupId,
              targetDate: selected,
            );

      final members = await membersFuture;
      final todayDashboard = await todayDashboardFuture;
      final dashboard = await selectedDashboardFuture;

      List<FamilyInvitation> pendingSent = const [];
      try {
        final groupInvitations =
            await _familyService.getGroupInvitations(groupId);
        pendingSent =
            groupInvitations.where((item) => item.isPending).toList();
      } catch (_) {
        pendingSent = const [];
      }

      int? selectedUserId = _selectedUserId;
      if (members.isEmpty) {
        selectedUserId = null;
      } else if (selectedUserId == null ||
          !members.any((member) => member.userId == selectedUserId)) {
        selectedUserId = members.first.userId;
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _groupPendingInvitations = pendingSent;
        _todayDashboard = todayDashboard;
        _dashboard = dashboard;
        _selectedUserId = selectedUserId;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateSheetFractions();
      });

      await Future.wait([
        _loadWeekStats(groupId, selectedUserId),
        _loadMedicationsForSelectedMember(),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '그룹 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadWeekStats(int groupId, int? userId) async {
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _totalByDay = {};
        _doneByDay = {};
      });
      return;
    }

    final weekStart = _startOfWeekSun(_selectedDate);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final totalByDay = <DateTime, int>{};
    final doneByDay = <DateTime, int>{};

    await Future.wait(
      days.map((day) async {
        try {
          final dashboard = await _familyService.getDashboard(
            groupId: groupId,
            targetDate: day,
          );
          final summary = dashboard.summaryFor(userId);
          final key = dateKey(day);
          totalByDay[key] = summary?.totalScheduled ?? 0;
          doneByDay[key] = summary?.takenCount ?? 0;
        } catch (_) {
          totalByDay[dateKey(day)] = 0;
          doneByDay[dateKey(day)] = 0;
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      _totalByDay = totalByDay;
      _doneByDay = doneByDay;
    });
  }

  Future<void> _loadMedicationsForSelectedMember() async {
    final userId = _selectedUserId;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _medications = []);
      return;
    }

    setState(() => _isLoadingMedications = true);
    try {
      final dayOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final currentUserIdStr = await UserStore.getCurrentUserId();
      final currentUserId = int.tryParse(currentUserIdStr ?? '');
      final isOtherMember =
          currentUserId != null && userId != currentUserId;

      final meds = isOtherMember
          ? await MedicationService.fetchFamilyMemberMedications(
              userId,
              dayOnly,
              dayOnly,
            )
          : await MedicationService.fetchMedications(dayOnly, dayOnly);

      if (!mounted) return;
      setState(() {
        _medications = meds;
        _isLoadingMedications = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _medications = [];
        _isLoadingMedications = false;
      });
    }
  }

  Future<void> _onMemberSelected(int userId) async {
    if (_selectedUserId == userId) return;

    setState(() {
      _selectedUserId = userId;
      _selectedDate = DateTime.now();
    });

    final groupId = _selectedGroup?.id;
    if (groupId == null) return;

    try {
      final dashboard = await _familyService.getDashboard(
        groupId: groupId,
        targetDate: _todayDate,
      );
      if (mounted) {
        setState(() {
          _todayDashboard = dashboard;
          _dashboard = dashboard;
        });
      }
    } catch (_) {}

    await Future.wait([
      _loadWeekStats(groupId, userId),
      _loadMedicationsForSelectedMember(),
    ]);
  }

  Future<void> _onGroupSelected(FamilyGroup group) async {
    setState(() {
      _selectedGroup = group;
      _selectedUserId = null;
      _selectedDate = DateTime.now();
    });
    await _loadGroupData(group.id);
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() => _selectedDate = date);
    final groupId = _selectedGroup?.id;
    if (groupId == null) return;

    try {
      final dashboard = await _familyService.getDashboard(
        groupId: groupId,
        targetDate: date,
      );
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
      await Future.wait([
        _loadWeekStats(groupId, _selectedUserId),
        _loadMedicationsForSelectedMember(),
      ]);
    } catch (_) {}
  }

  Future<void> _handleInvitation({
    required FamilyInvitation invitation,
    required bool accept,
  }) async {
    if (_processingInvitationId != null) return;

    final groupName = invitation.groupName?.trim();
    final hasGroupName = groupName != null && groupName.isNotEmpty;
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: accept ? '그룹 초대 수락' : '그룹 초대 거절',
      message: accept
          ? (hasGroupName
              ? '\'$groupName\' 그룹 초대를 수락하시겠습니까?'
              : '가족 그룹 초대를 수락하시겠습니까?')
          : (hasGroupName
              ? '\'$groupName\' 그룹 초대를 거절하시겠습니까?'
              : '가족 그룹 초대를 거절하시겠습니까?'),
      cancelLabel: '취소',
      confirmLabel: accept ? '수락하기' : '거절하기',
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingInvitationId = invitation.id);
    try {
      if (accept) {
        await _familyService.acceptInvitation(invitation.id);
      } else {
        await _familyService.declineInvitation(invitation.id);
      }
      await _loadPageData();
    } catch (_) {
      if (!mounted) return;
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '알림',
        message: accept ? '초대 수락에 실패했습니다.' : '초대 거절에 실패했습니다.',
        confirmLabel: '확인',
      );
    } finally {
      if (mounted) {
        setState(() => _processingInvitationId = null);
      }
    }
  }

  Future<void> _openInviteFlow() async {
    final group = _selectedGroup;
    if (group == null) {
      await _openCreateGroup();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyInviteExistingGroupInvitePage(
          groupId: group.id,
          groupName: group.name,
        ),
      ),
    );
    await _loadPageData();
  }

  Future<void> _openGroupManage() async {
    final group = _selectedGroup;
    if (group == null) {
      await _openCreateGroup();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FamilyGroupManagePage(groupId: group.id, groupName: group.name),
      ),
    );
    await _loadPageData();
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FamilyInviteGroupSelectPage()),
    );
    await _loadPageData();
  }

  void _showGroupMenu() {
    if (_groups.isEmpty) {
      _openCreateGroup();
      return;
    }

    final buttonContext = _groupDropdownKey.currentContext;
    if (buttonContext == null) return;

    final RenderBox button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<String>(
      context: context,
      constraints: const BoxConstraints(minWidth: 0),
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height + 2,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy - button.size.height,
      ),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      elevation: 3,
      items: [
        ..._groups.map((group) {
          final isSelected = _selectedGroup?.id == group.id;
          return PopupMenuItem<String>(
            value: 'group_${group.id}',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF235DFF)
                          : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, color: Color(0xFF235DFF), size: 14),
              ],
            ),
          );
        }),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'create',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Color(0xFF235DFF), size: 14),
              SizedBox(width: 4),
              Text('새 그룹 생성하기', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'create') {
        _openCreateGroup();
        return;
      }
      if (!value.startsWith('group_')) return;
      final groupId = int.tryParse(value.substring(6));
      if (groupId == null) return;
      for (final group in _groups) {
        if (group.id == groupId) {
          _onGroupSelected(group);
          break;
        }
      }
    });
  }

  Map<int, MemberMedicationSummary> get _summariesByUserId {
    final map = <int, MemberMedicationSummary>{};
    for (final summary in _todayDashboard?.membersSummary ?? const []) {
      map[summary.userId] = summary;
    }
    return map;
  }

  String _selectedMemberName() {
    for (final member in _members) {
      if (member.userId == _selectedUserId) {
        return member.userName ?? '가족';
      }
    }
    return '가족';
  }

  MemberMedicationSummary? get _selectedSummary {
    final userId = _selectedUserId;
    if (userId == null) return null;
    return _dashboard?.summaryFor(userId);
  }

  @override
  Widget build(BuildContext context) {
    const lightBlueBg = Color(0xFFEAF2FF);
    final hasGroups = !_isLoading && _groups.isNotEmpty;
    final summary = _selectedSummary;
    final memberName = _selectedMemberName();
    final sheetTitle = memberName.trim().isEmpty
        ? '복용 현황'
        : '$memberName 복용 현황';

    return Scaffold(
      backgroundColor: _groups.isEmpty
          ? Colors.white
          : const Color(0xFFEAF2FF),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                key: _stackKey,
                fit: StackFit.expand,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      if (_errorMessage != null) _buildErrorBanner(),
                      if (_pendingInvitations.isNotEmpty)
                        ..._pendingInvitations.map(
                          (invitation) => FamilyInvitationBanner(
                            key: ValueKey(invitation.id),
                            invitation: invitation,
                            isProcessing:
                                _processingInvitationId == invitation.id,
                            onAccept: () => _handleInvitation(
                              invitation: invitation,
                              accept: true,
                            ),
                            onDecline: () => _handleInvitation(
                              invitation: invitation,
                              accept: false,
                            ),
                          ),
                        ),
                      if (_groups.isEmpty)
                        Expanded(child: _buildEmptyState(context))
                      else ...[
                        KeyedSubtree(
                          key: _memberRowKey,
                          child: FamilyMemberRow(
                            members: _members,
                            pendingInvitations: _groupPendingInvitations,
                            summariesByUserId: _summariesByUserId,
                            selectedUserId: _selectedUserId,
                            onMemberSelected: _onMemberSelected,
                            onAddMember: _openInviteFlow,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: lightBlueBg,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasGroups && _minInitialSheetFraction != null)
                    DraggableScrollableSheet(
                      controller: _dragController,
                      expand: false,
                      snap: true,
                      snapSizes: [_minInitialSheetFraction!, 1.0],
                      minChildSize: _minInitialSheetFraction!,
                      initialChildSize: _minInitialSheetFraction!,
                      maxChildSize: 1.0,
                      builder: (context, scrollController) {
                        return MedicationRecordSheetContent(
                          scrollController: scrollController,
                          selectedDay: _selectedDate,
                          total: summary?.totalScheduled ?? 0,
                          done: summary?.takenCount ?? 0,
                          totalByDay: _totalByDay,
                          doneByDay: _doneByDay,
                          medications: _medications,
                          isLoading: _isLoadingMedications,
                          title: sheetTitle,
                          onDaySelected: _onDateSelected,
                          emptyMessage: (summary?.totalScheduled ?? 0) == 0
                              ? '등록된 복약 일정이 없습니다.'
                              : '선택한 날짜에 기록이 없습니다',
                        );
                      },
                    ),
                ],
              ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isEmpty = _groups.isEmpty;
    final groupName = _selectedGroup?.name ?? '우리 가족';
    final menuIconSize = Responsive.responsiveIconSize(context, 24);
    final menuVerticalPadding = Responsive.responsiveValue(context, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: EdgeInsets.only(
            top: Responsive.responsiveValue(context, 8),
            bottom: Responsive.responsiveValue(context, 2),
          ),
          padding: Responsive.responsivePadding(context, 16, 0),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              if (!isEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openGroupManage,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.responsiveValue(context, 10),
                      vertical: menuVerticalPadding,
                    ),
                    child: Icon(
                      Icons.menu_rounded,
                      color: Colors.black87,
                      size: menuIconSize,
                    ),
                  ),
                )
              else
                SizedBox(height: menuIconSize + (menuVerticalPadding * 2)),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: Responsive.responsiveValue(context, 22),
            right: Responsive.responsiveValue(context, 16),
            bottom: Responsive.responsiveValue(context, 5),
          ),
          decoration: isEmpty
              ? null
              : BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(
                    Responsive.responsiveValue(context, 12),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEmpty)
                Text(
                  groupName,
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 22),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                )
              else
                GestureDetector(
                  key: _groupDropdownKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _showGroupMenu,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        groupName,
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 22),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                ),
              SizedBox(height: Responsive.responsiveHeight(context, 6)),
              Text(
                isEmpty ? '가족은 잘 챙겨먹고 있으려나?' : '우리가족은 잘 챙겨먹고 있으려나?',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 14),
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.responsiveHeight(context, 12)),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 20, 0, 20, 8),
      child: Text(
        _errorMessage!,
        style: TextStyle(
          color: Colors.red[700],
          fontSize: Responsive.responsiveFontSize(context, 13),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return FamilyEmptyState(onCreateGroup: _openCreateGroup);
  }
}
