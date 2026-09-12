import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';
import 'package:after30/features/home/ui/widgets/home_utils.dart';
import 'package:after30/features/home/ui/widgets/home_date_header.dart';
import 'package:after30/features/home/ui/widgets/empty_medicine_section.dart';
import 'package:after30/features/home/ui/widgets/add_medicine_tile.dart';
import 'package:after30/features/home/ui/widgets/home_family_gauge_row.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';
import 'package:after30/utils/responsive.dart';

class HomeContent extends StatefulWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final FamilyService _familyService = FamilyService();
  final Set<String> _processingDoseKeys = <String>{};

  // 캘린더(calendar_page.dart)의 firstDay/lastDay 와 동일한 기준을 사용한다.
  static final DateTime _minSelectableDate = DateTime(2000, 1, 1);
  static final DateTime _maxSelectableDate = DateTime(2100, 12, 31);

  DateTime _selectedDate = DateTime.now();
  List<Medication> _medications = [];
  bool _isLoading = true;

  List<MemberMedicationSummary> _familyMembers = [];
  Map<int, int> _userIdToGroupId = {};

  @override
  void initState() {
    super.initState();
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
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => FamilyPage(initialGroupId: groupId),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _openCreateGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FamilyInviteGroupSelectPage()),
    );
    await _loadFamilyDashboard();
  }

  Future<void> _loadDosesForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await MedicationService.fetchMedications(date, date);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e))),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingDoseKeys.remove(doseKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Medication> dayMeds = [..._medications]
      ..sort((a, b) => a.time.compareTo(b.time));
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    const skyBlue = Color(0xFFEBF0FF);

    return Scaffold(
      backgroundColor: skyBlue,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단: 흰 배경 (가족 게이지)
          Container(
            color: Colors.white,
            child: SafeArea(
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
          ),
          // 하단: 하늘색 배경 + 복약 체크리스트
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
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
                            onPreviousDay: _canGoPreviousDay
                                ? () => _changeDate(-1)
                                : null,
                            onNextDay: _canGoNextDay
                                ? () => _changeDate(1)
                                : null,
                          ),
                          SizedBox(
                            height: Responsive.responsiveHeight(context, 8),
                          ),
                          if (_isLoading)
                            Padding(
                              padding: EdgeInsets.all(
                                Responsive.responsiveValue(context, 24),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
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
                                isProcessing: _processingDoseKeys.contains(
                                  doseKey,
                                ),
                                onMarkCompleted: _markCompleted,
                                onMarkUncompleted: _markUncompleted,
                              );
                            }),
                            SizedBox(
                              height: Responsive.responsiveHeight(context, 8),
                            ),
                            AddMedicineTile(onAdd: _goToRegister),
                            SizedBox(
                              height: Responsive.responsiveHeight(context, 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 120 + bottomSafe,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
