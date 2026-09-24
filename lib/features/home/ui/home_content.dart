import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';
import 'package:after30/features/home/ui/widgets/empty_medicine_section.dart';
import 'package:after30/features/home/ui/widgets/add_medicine_tile.dart';
import 'package:after30/features/home/ui/widgets/home_family_gauge_row.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';
import 'package:after30/utils/responsive.dart';

class HomeContent extends StatefulWidget {
  final User? user;

  /// 복약 목록 조회 함수 주입 지점(테스트/디버그 프리뷰용). 지정하지 않으면
  /// 실제 서비스([MedicationService.fetchMedications])를 사용한다.
  final FetchMedicationsFn? fetchMedications;

  /// 가족 대시보드 조회 서비스 주입 지점(테스트/디버그 프리뷰용). 지정하지
  /// 않으면 실제 [FamilyService]를 사용한다.
  final FamilyService? familyService;

  /// "오늘"을 계산하는 데 쓰는 시계 주입 지점(테스트용). 지정하지 않으면
  /// 실제 [DateTime.now]를 쓴다(리뷰 M1 — 셸 전역 플래그 대신 화면이 직접
  /// 자정 롤오버를 감지할 수 있도록 결정론적으로 테스트하기 위함).
  final DateTime Function() now;

  const HomeContent({
    super.key,
    required this.user,
    this.fetchMedications,
    this.familyService,
    this.now = DateTime.now,
  });

  @override
  State<HomeContent> createState() => HomeContentState();
}

/// `HomePage`(M2 탭 재활성화 훅)가 `GlobalKey<HomeContentState>`로 이
/// 상태에 접근해 [onTabActivated]를 호출할 수 있도록 공개 타입으로 둔다.
class HomeContentState extends State<HomeContent> {
  late final FamilyService _familyService = widget.familyService ?? FamilyService();
  late final FetchMedicationsFn _fetchMedications =
      widget.fetchMedications ?? MedicationService.fetchMedications;
  late final DateTime Function() _now = widget.now;
  final Set<String> _processingDoseKeys = <String>{};

  // 캘린더(calendar_page.dart)의 firstDay/lastDay 와 동일한 기준을 사용한다.
  static final DateTime _minSelectableDate = DateTime(2000, 1, 1);
  static final DateTime _maxSelectableDate = DateTime(2100, 12, 31);

  late DateTime _selectedDate;

  /// 마지막으로 확인한 "오늘" 날짜(리뷰 M1). 탭 재활성화 훅에서 이 값과
  /// 현재 시계를 비교해 스스로 자정 롤오버를 판단한다 — 더 이상
  /// `AppShell.dateChangedOnLastActivation`(셸 전역, 탭 하나에만 적용되는
  /// 일회성 플래그)에 의존하지 않는다. 그 플래그는 활성화 시점에 활성
  /// 탭에만 적용되고 곧바로 리셋되므로, 다른 탭에 있는 동안 날짜가
  /// 바뀌면 그 탭은 영영 신호를 받지 못했다.
  late DateTime _lastSeenDay;

  List<Medication> _medications = [];
  bool _isLoading = true;

  /// 응답 경쟁(리뷰 M3) 방지용 요청 일련번호. 매 `_loadDosesForDate`
  /// 호출마다 증가시키고, 응답이 돌아왔을 때 이 값이 최신 요청과 다르면
  /// (더 최근 요청이 이미 나갔으면) 그 응답은 버린다.
  int _loadSeq = 0;

  List<MemberMedicationSummary> _familyMembers = [];
  Map<int, int> _userIdToGroupId = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(_now());
    _lastSeenDay = _selectedDate;
    _loadDosesForDate(_selectedDate);
    _loadFamilyDashboard();
  }

  Future<void> _loadFamilyDashboard() async {
    try {
      final results = await Future.wait([
        _familyService.getHomeDashboard(),
        _familyService.getUserIdToGroupIdMap(),
      ]);
      final dashboard = results[0] as HomeDashboard;
      final groupMap = results[1] as Map<int, int>;
      if (!mounted) return;
      setState(() {
        _familyMembers = dashboard.membersSummary;
        _userIdToGroupId = groupMap;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _familyMembers = [];
        _userIdToGroupId = {};
      });
    }
  }

  Future<void> _openFamilyGroupForMember(MemberMedicationSummary member) async {
    final groupId = _userIdToGroupId[member.userId];
    // 앱 셸 안에서는 가족 탭으로 전환하며 해당 그룹을 바로 연다
    // (plan §6 W10 5항). groupId가 null일 수도 있는데(매핑을 못 찾은 경우),
    // 이때도 가족 탭 루트를 다시 만들어 "그룹 미지정" 초기 상태로
    // 되돌린다 — arguments만 넘기면 switchTab이 null 인자를 "새로 만들
    // 필요 없음"으로 해석해 이전에 열어뒀던 다른 그룹이 그대로 남는
    // 문제가 있었다(M6). resetArguments로 null이어도 강제로 다시 만든다.
    AppShell.of(context).switchTab(
      AppShellTab.family,
      popToRoot: true,
      arguments: groupId,
      resetArguments: true,
    );
  }

  /// AppShell 탭 재활성화(M2) 훅에서 호출된다. 다른 탭에 있다가 홈 탭으로
  /// 돌아왔을 때 최신 데이터를 다시 불러온다.
  ///
  /// 마지막으로 이 화면이 본 날짜([_lastSeenDay])와 지금 시계를 비교해
  /// 스스로 자정 롤오버를 판단한다(리뷰 M1). 날짜가 바뀌었을 때만 선택
  /// 날짜를 오늘로 되돌리고 전체 목록 로딩 표시를 보여준다 — 날짜가
  /// 그대로면 사용자가 보던 목록을 유지한 채 조용히 갱신한다(리뷰 m3).
  ///
  /// 당겨서 새로고침(iOS `CupertinoSliverRefreshControl`)은 이 메서드가
  /// 아니라 [refresh]를 쓴다 — 활성화 훅과 새로고침을 같은 메서드로
  /// 묶으면, 자정 롤오버로 발동한 날짜 리셋 신호가 그 뒤의 새로고침에도
  /// 남아 있어 사용자가 고른 과거 날짜를 도로 오늘로 튕겨버렸다(리뷰 M2).
  Future<void> onTabActivated() async {
    final today = _dateOnly(_now());
    final dayChanged = today != _lastSeenDay;
    _lastSeenDay = today;
    if (dayChanged && mounted) {
      setState(() => _selectedDate = today);
    }
    await Future.wait([
      _loadDosesForDate(_selectedDate, showSpinner: dayChanged),
      _loadFamilyDashboard(),
    ]);
  }

  /// 당겨서 새로고침 전용(리뷰 M2). 현재 선택된 날짜의 데이터만 조용히
  /// 다시 불러올 뿐, 날짜를 바꾸거나 자정 롤오버를 검사하지 않는다.
  Future<void> refresh() async {
    await Future.wait([
      _loadDosesForDate(_selectedDate, showSpinner: false),
      _loadFamilyDashboard(),
    ]);
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FamilyInviteGroupSelectPage()),
    );
    await _loadFamilyDashboard();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [showSpinner]가 true면 목록 전체를 로딩 인디케이터로 잠깐 가린다
  /// (초기 로드/날짜 변경 시). false면 기존 목록을 그대로 둔 채 응답이
  /// 오면 조용히 교체한다(탭 재활성화·당겨서 새로고침, 리뷰 m3).
  Future<void> _loadDosesForDate(DateTime date, {bool showSpinner = true}) async {
    final req = ++_loadSeq;
    if (showSpinner) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final items = await _fetchMedications(date, date);
      // 응답이 도착했을 때 이미 더 최신 요청이 나갔거나(req != _loadSeq),
      // 그 사이 사용자가 다른 날짜로 옮겨갔으면(리뷰 M3) 이 응답은 버린다.
      if (!mounted || req != _loadSeq || !_isSameDay(date, _selectedDate)) return;
      setState(() {
        _medications = items
            .where(
              (m) =>
                  m.date.year == date.year &&
                  m.date.month == date.month &&
                  m.date.day == date.day,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || req != _loadSeq || !_isSameDay(date, _selectedDate)) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goToRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineRegisterPage()),
    );
    await _loadDosesForDate(_selectedDate);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _canGoPreviousDay =>
      _dateOnly(_selectedDate).isAfter(_minSelectableDate);

  bool get _canGoNextDay =>
      _dateOnly(_selectedDate).isBefore(_maxSelectableDate);

  void _changeDate(int deltaDays) {
    final candidate = _selectedDate.add(Duration(days: deltaDays));
    final candidateOnly = _dateOnly(candidate);
    if (candidateOnly.isBefore(_minSelectableDate) ||
        candidateOnly.isAfter(_maxSelectableDate)) {
      return;
    }
    setState(() {
      _selectedDate = candidate;
    });
    _loadDosesForDate(_selectedDate);
  }

  /// 서버 에러(DioException)에서 사용자에게 보여줄 메시지를 뽑아낸다.
  /// 서버가 detail 을 문자열로 내려주면 그대로 보여주고, 그렇지 않으면 일반 문구를 사용한다.
  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    return '처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.';
  }

  Future<bool> _markCompleted(String doseKey) async {
    final parts = doseKey.split('_');
    if (parts.length < 3) return false;
    final scheduleId = int.tryParse(parts[0]);
    if (scheduleId == null) return false;
    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr = parts[2];

    if (_processingDoseKeys.contains(doseKey)) return false;
    setState(() => _processingDoseKeys.add(doseKey));
    try {
      final hs = HistoryService();
      // 같은 일정/시간의 히스토리가 있으면 PUT으로 taken + taken_at 갱신,
      // 없으면 process API로 신규 완료 처리
      int? historyId;
      try {
        final list = await hs.getUserHistories(
          startDate: dateStr,
          endDate: dateStr,
        );
        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final sid = (item['schedule_id'] as num?)?.toInt();
          final scheduledTime = (item['scheduled_time'] ?? '').toString();
          if (sid == scheduleId &&
              (scheduledTime == timeStr ||
                  scheduledTime.startsWith(timeStr))) {
            historyId = (item['id'] as num?)?.toInt();
            break;
          }
        }
      } catch (_) {}
      if (historyId != null) {
        await hs.updateHistoryStatus(
          historyId: historyId,
          status: 'taken',
          takenAt: DateTime.now(),
        );
      } else {
        await hs.markTaken(
          scheduleId: scheduleId,
          scheduledDate: dateStr,
          scheduledTime: timeStr,
        );
      }
      await _loadDosesForDate(_selectedDate);
      return true;
    } catch (e) {
      if (mounted) {
        AppToast.show(context, _extractErrorMessage(e), type: AppToastType.error);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _processingDoseKeys.remove(doseKey));
      }
    }
  }

  Future<void> _markUncompleted(String doseKey) async {
    final parts = doseKey.split('_');
    if (parts.length < 3) return;
    final scheduleId = int.tryParse(parts[0]);
    if (scheduleId == null) return;
    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr = parts[2];

    if (_processingDoseKeys.contains(doseKey)) return;
    setState(() => _processingDoseKeys.add(doseKey));
    try {
      final hs = HistoryService();
      // 선택한 날짜의 히스토리에서 해당 일정의 완료 기록을 찾아 ID로 상태 업데이트
      final list = await hs.getUserHistories(
        startDate: dateStr,
        endDate: dateStr,
      );
      int? historyId;
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final sid = (item['schedule_id'] as num?)?.toInt();
        final scheduledTime = (item['scheduled_time'] ?? '').toString();
        if (sid == scheduleId &&
            (scheduledTime == timeStr ||
                scheduledTime.startsWith(timeStr))) {
          historyId = (item['id'] as num?)?.toInt();
          break;
        }
      }
      if (historyId != null) {
        await hs.updateHistoryStatus(
          historyId: historyId,
          status: 'cancelled',
        );
      }
      await _loadDosesForDate(_selectedDate);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, _extractErrorMessage(e), type: AppToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _processingDoseKeys.remove(doseKey));
      }
    }
  }

  /// 상단 가족 게이지 행(흰 배경). Android는 자체 [SafeArea]로 상단 여백을
  /// 확보하고, iOS는 [AppSliverNavBar]가 이미 상단 안전 영역을 처리하므로
  /// [topSafeArea]를 false로 받아 중복 여백을 만들지 않는다.
  Widget _buildFamilyGaugeSection(BuildContext context, {required bool topSafeArea}) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: topSafeArea,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: Responsive.responsiveHeight(context, 8)),
            HomeFamilyGaugeRow(
              members: _familyMembers,
              onMemberTap: _openFamilyGroupForMember,
              onAddTap: _openCreateGroup,
            ),
          ],
        ),
      ),
    );
  }

  /// 하단 하늘색 배경 + 복약 체크리스트(제목 + 흰 카드). 두 플랫폼 모두
  /// 동일한 내용을 쓰되, iOS 카드 곡률/그림자는 [MedicationDoseTile]과
  /// [EmptyMedicineSection] 내부에서 각각 토큰으로 분기한다.
  Widget _buildChecklistSection(
    BuildContext context,
    List<Medication> dayMeds,
    double bottomSafe,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.responsiveValue(context, 22),
            right: Responsive.responsiveValue(context, 16),
            top: Responsive.responsiveValue(context, 8),
            bottom: Responsive.responsiveValue(context, 5),
          ),
          child: const PageTitle(
            title: '나의 복약 체크 리스트',
            margin: EdgeInsets.zero,
          ),
        ),
        SizedBox(height: Responsive.responsiveHeight(context, 12)),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.responsiveValue(context, 16),
              Responsive.responsiveValue(context, 24),
              Responsive.responsiveValue(context, 16),
              Responsive.responsiveValue(context, 24) + bottomSafe,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                HomeDateHeader(
                  selectedDate: _selectedDate,
                  onPreviousDay: _canGoPreviousDay ? () => _changeDate(-1) : null,
                  onNextDay: _canGoNextDay ? () => _changeDate(1) : null,
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 8)),
                if (_isLoading)
                  Padding(
                    padding: EdgeInsets.all(Responsive.responsiveValue(context, 24)),
                    child: const Center(child: AppActivityIndicator()),
                  )
                else if (dayMeds.isEmpty)
                  EmptyMedicineSection(onAdd: _goToRegister)
                else ...[
                  ...dayMeds.map((m) {
                    final doseKey =
                        '${m.scheduleId ?? m.id}_${yyyymmdd(_selectedDate)}_${m.time}';
                    return MedicationDoseTile(
                      medication: m,
                      selectedDate: _selectedDate,
                      doseKey: doseKey,
                      isProcessing: _processingDoseKeys.contains(doseKey),
                      onMarkCompleted: _markCompleted,
                      onMarkUncompleted: _markUncompleted,
                    );
                  }),
                  SizedBox(height: Responsive.responsiveHeight(context, 8)),
                  AddMedicineTile(onAdd: _goToRegister),
                  SizedBox(height: Responsive.responsiveHeight(context, 10)),
                ],
              ],
            ),
          ),
        ),
        Container(height: 120 + bottomSafe, color: Colors.white),
      ],
    );
  }

  /// Android: 기존 화면 그대로(Column + SafeArea + SingleChildScrollView).
  /// 당겨서 새로고침은 iOS 전용이라(리뷰 m1, 팀 리드 결정) Android는
  /// `RefreshIndicator`를 붙이지 않고 원래 구조를 그대로 유지한다.
  Widget _buildAndroid(
    BuildContext context,
    List<Medication> dayMeds,
    double bottomSafe,
  ) {
    const skyBlue = Color(0xFFEBF0FF);
    return Scaffold(
      backgroundColor: skyBlue,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFamilyGaugeSection(context, topSafeArea: true),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: _buildChecklistSection(context, dayMeds, bottomSafe),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS: [AppSliverNavBar]로 선택한 날짜를 큰 제목으로 보여주고,
  /// [CupertinoSliverRefreshControl]로 당겨서 새로고침을 지원한다(§6 W7).
  /// 새로고침은 날짜를 바꾸지 않는 [refresh]에 연결한다(리뷰 M2).
  Widget _buildIOS(
    BuildContext context,
    List<Medication> dayMeds,
    double bottomSafe,
  ) {
    const skyBlue = Color(0xFFEBF0FF);
    final now = _now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final title = isToday ? '오늘' : formatKoreanDate(_selectedDate);

    return Scaffold(
      backgroundColor: skyBlue,
      body: CustomScrollView(
        slivers: [
          AppSliverNavBar(title: title, showBackButton: false),
          CupertinoSliverRefreshControl(onRefresh: refresh),
          SliverToBoxAdapter(child: _buildFamilyGaugeSection(context, topSafeArea: false)),
          SliverToBoxAdapter(child: _buildChecklistSection(context, dayMeds, bottomSafe)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Medication> dayMeds = [..._medications]
      ..sort((a, b) => a.time.compareTo(b.time));
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return isCupertino(context)
        ? _buildIOS(context, dayMeds, bottomSafe)
        : _buildAndroid(context, dayMeds, bottomSafe);
  }
}
