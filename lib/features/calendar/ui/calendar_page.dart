import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_day_widgets.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_utils.dart';
import 'package:after30/features/calendar/ui/widgets/pinned_header_delegate.dart';
import 'package:after30/features/calendar/ui/widgets/medication_tile.dart';
import 'package:after30/features/calendar/ui/widgets/week_strip.dart';
import 'package:after30/features/calendar/ui/widgets/calendar_month_header.dart';
import 'package:after30/features/calendar/ui/widgets/medication_sheet_header.dart';
import 'package:after30/utils/responsive.dart';

class CalendarPage extends StatefulWidget {
  /// 복약 목록 조회 함수 주입 지점(테스트/디버그 프리뷰용). 지정하지 않으면
  /// 실제 서비스([MedicationService.fetchMedications])를 사용한다.
  final FetchMedicationsFn? fetchMedications;

  /// "오늘"을 계산하는 데 쓰는 시계 주입 지점(테스트용). 지정하지 않으면
  /// 실제 [DateTime.now]를 쓴다(리뷰 M1 — 셸 전역 플래그 대신 화면이 직접
  /// 자정 롤오버를 감지할 수 있도록 결정론적으로 테스트하기 위함).
  final DateTime Function() now;

  const CalendarPage({super.key, this.fetchMedications, this.now = DateTime.now});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final FetchMedicationsFn _fetchMedications =
      widget.fetchMedications ?? MedicationService.fetchMedications;
  late final DateTime Function() _now = widget.now;

  late DateTime _focusedDay;
  DateTime? _selectedDay;

  /// 마지막으로 확인한 "오늘" 날짜(리뷰 M1). 탭 재활성화 훅에서 이 값과
  /// 현재 시계를 비교해 자정이 지났는지 스스로 판단한다 — 더 이상
  /// `AppShell.dateChangedOnLastActivation`(셸 전역, 탭 하나에만 적용되는
  /// 일회성 플래그)에 의존하지 않는다.
  late DateTime _lastSeenDay;

  final Map<DateTime, int> _totalByDay = {};
  final Map<DateTime, int> _doneByDay = {};
  final Map<DateTime, List<Medication>> _medsByDay = {};
  bool _sheetVisible = false;
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  final GlobalKey _monthHeaderKey = GlobalKey();
  final GlobalKey _calendarCardKey = GlobalKey();
  double? _minInitialSheetFraction;

  /// 응답 경쟁(리뷰 M3) 방지용 요청 일련번호. 매 `_loadMonth` 호출마다
  /// 증가시키고, 응답이 돌아왔을 때 이 값이 최신 요청과 다르면(더 최근
  /// 요청이 이미 나갔으면) 그 응답은 버린다.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _focusedDay = _now();
    _lastSeenDay = dateKey(_focusedDay);
    // 첫 진입 시 오늘 날짜를 선택하고 시트를 보이도록 설정
    _selectedDay = dateKey(_focusedDay);
    _sheetVisible = true;
    _loadMonth(_focusedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateSheetFractions();
    });
  }

  void _recalculateSheetFractions() {
    if (!_sheetVisible) return; // 시트가 보일 때만 계산애니메이션
    final headerCtx = _monthHeaderKey.currentContext;
    final cardCtx = _calendarCardKey.currentContext;
    if (headerCtx == null || cardCtx == null) return;
    final headerBox = headerCtx.findRenderObject() as RenderBox?;
    final cardBox = cardCtx.findRenderObject() as RenderBox?;
    if (headerBox == null || cardBox == null) return;
    final headerTop = headerBox.localToGlobal(Offset.zero).dy;
    // 카드 위치는 현재 초기 위치 계산에 직접 사용하지 않음 (향후 확장 대비 측정 유지)
    final screenHeight = MediaQuery.of(context).size.height;

    final maxFraction = ((screenHeight - headerTop) / screenHeight).clamp(
      0.43,
      0.95,
    );
    // 초기 위치를 화면 "맨 아래"에 가깝게 (핸들바만 보이도록) 고정
    // max 대비 여유는 0.02 남김
    final initialFraction = (0.43).clamp(0.1, maxFraction - 0.02);

    if (!mounted) return;
    setState(() {
      _minInitialSheetFraction = initialFraction;
    });
    // 첫 프레임에서도 아래 위치로 보장
    try {
      if (_minInitialSheetFraction != null) {
        // 이미 사용자가 시트를 더 올려둔 상태라면, 현재 위치를 유지하고 내려가지 않도록 함
        final current = _dragController.size;
        if (current <= (_minInitialSheetFraction! + 0.001)) {
          _dragController.animateTo(
            _minInitialSheetFraction!,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  /// AppShell 탭 재활성화(M2) 훅에서 호출된다(§6 W7 — 예: 홈 탭에서 복용
  /// 완료로 기록한 뒤 기록 탭으로 돌아오면 최신 상태가 반영돼야 한다).
  ///
  /// 마지막으로 이 화면이 본 날짜([_lastSeenDay])와 지금 시계를 비교해
  /// 스스로 자정 롤오버를 판단한다(리뷰 M1). 셸 전역
  /// `AppShell.dateChangedOnLastActivation`은 탭 하나가 활성화될 때 한 번만
  /// true였다가 곧바로 false로 리셋되는 값이라, 그 순간 다른 탭에 있었으면
  /// 그 탭은 영영 리셋 신호를 받지 못했다 — 각 화면이 자기 시계 비교로
  /// 직접 판단하면 어느 탭에 있었든, 몇 번을 오갔든 다음에 활성화될 때
  /// 정확히 한 번 리셋된다.
  Future<void> onTabActivated() async {
    final today = dateKey(_now());
    final dayChanged = today != _lastSeenDay;
    _lastSeenDay = today;
    if (dayChanged) {
      setState(() {
        _focusedDay = today;
        _selectedDay = today;
      });
    }
    await _loadMonth(_focusedDay);
    if (dayChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetVisible) _recalculateSheetFractions();
      });
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  Future<void> _loadMonth(DateTime anyDayInMonth) async {
    final req = ++_loadSeq;
    final requestedMonth = DateTime(anyDayInMonth.year, anyDayInMonth.month);
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    try {
      final List<Medication> meds = await _fetchMedications(first, last);
      final totalsByDay = <DateTime, int>{};
      final completedByDay = <DateTime, int>{};
      final medsByDay = <DateTime, List<Medication>>{};
      for (final m in meds) {
        final key = dateKey(m.date);
        totalsByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        if ((m.status).toLowerCase() == 'taken') {
          completedByDay.update(key, (v) => v + 1, ifAbsent: () => 1);
        }
        medsByDay.putIfAbsent(key, () => <Medication>[]).add(m);
      }
      // 응답이 도착했을 때 이미 더 최신 요청이 나갔거나(req != _loadSeq),
      // 그 사이 화면이 다른 달로 옮겨갔으면(리뷰 M3) 이 응답은 버린다.
      if (!mounted || req != _loadSeq || !_isSameMonth(requestedMonth, _focusedDay)) return;
      setState(() {
        _totalByDay
          ..clear()
          ..addAll(totalsByDay);
        _doneByDay
          ..clear()
          ..addAll(completedByDay);
        _medsByDay
          ..clear()
          ..addAll(medsByDay);
      });
    } catch (_) {
      if (!mounted || req != _loadSeq || !_isSameMonth(requestedMonth, _focusedDay)) return;
      setState(() {
        _totalByDay.clear();
        _doneByDay.clear();
        _medsByDay.clear();
      });
    }
  }

  Widget _buildBaseDay(DateTime day, Color primaryBlue) {
    final key = dateKey(day);
    final today = DateTime.now();
    final todayKey = dateKey(today);
    final isFuture = key.isAfter(todayKey);
    final total = _totalByDay[key] ?? 0;
    final done = _doneByDay[key] ?? 0;
    final text = day.day.toString();
    // 미래 날짜는 게이지 숨김 (월간/주간 공통 정책)
    if (isFuture) {
      return Center(
        child: Container(
          width: kDaySize,
          height: kDaySize,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (total == 0) {
      return Center(
        child: Container(
          width: kDaySize,
          height: kDaySize,
          alignment: Alignment.center,
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      );
    }
    if (done >= total) {
      return FilledDay(text: text, bg: primaryBlue, fg: Colors.white);
    }
    final percent = total > 0 ? (done / total) : 0.0;
    return GaugeDay(
      text: text,
      percent: percent,
      track: const Color(0xFFEDEFF2),
      progress: primaryBlue,
    );
  }

  /// iOS 전용 "오늘" 셀(§6 W7): 다 완료했으면 채워진 원, 아니면 브랜드
  /// 컬러 아웃라인 원으로 항상 "오늘"임을 표시한다(iOS 캘린더 느낌).
  /// Android는 이 빌더를 쓰지 않고 기존 [TableCalendar] 기본 스타일을
  /// 그대로 유지한다.
  Widget _buildTodayDayIOS(DateTime day, Color primaryBlue) {
    final key = dateKey(day);
    final total = _totalByDay[key] ?? 0;
    final done = _doneByDay[key] ?? 0;
    final text = day.day.toString();
    if (total > 0 && done >= total) {
      return FilledDay(text: text, bg: primaryBlue, fg: Colors.white);
    }
    return OutlinedDay(text: text, color: primaryBlue);
  }

  /// 월 제목을 탭하면 연/월 휠 피커로 바로 점프한다(§6 W7). 기존 캘린더
  /// 이동 범위(2000~2100)를 그대로 따른다.
  Future<void> _jumpToMonth() async {
    final picked = await showAppDatePicker(
      context: context,
      initial: _focusedDay,
      min: DateTime(2000),
      max: DateTime(2100, 12, 31),
      mode: AppDatePickerMode.monthYear,
    );
    if (picked == null) return;
    final next = DateTime(picked.year, picked.month, 1);
    setState(() => _focusedDay = next);
    _loadMonth(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetVisible) _recalculateSheetFractions();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    const lightBlueBg = Color(0xFFEAF2FF);

    List<Medication> medsForSelected() {
      final key = _selectedDay != null ? dateKey(_selectedDay!) : null;
      if (key == null) return const [];
      return _medsByDay[key] ?? const [];
    }

    final cupertino = isCupertino(context);

    return AppShellTabActivationListener(
      tabIndex: AppShellTab.history,
      onActivated: onTabActivated,
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                SizedBox(height: Responsive.responsiveHeight(context, 8)),
                Container(
                  key: _calendarCardKey,
                  margin: Responsive.responsiveMargin(context, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      Responsive.responsiveValue(context, 20),
                    ),
                  ),
                  child: Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      8,
                      8,
                      8,
                      20,
                    ),
                    child: Column(
                      children: [
                        CalendarMonthHeader(
                          focusedDay: _focusedDay,
                          monthHeaderKey: _monthHeaderKey,
                          // 리뷰 m1(팀 리드 결정): 월 제목 탭은 iOS 전용
                          // 기능이다. Android는 null을 넘겨 제목에 아무런
                          // 탭 핸들러도 붙지 않는 기존 구조를 그대로 유지한다.
                          onTitleTap: cupertino ? _jumpToMonth : null,
                          onPreviousMonth: () {
                            final prev = DateTime(
                              _focusedDay.year,
                              _focusedDay.month - 1,
                              1,
                            );
                            setState(() => _focusedDay = prev);
                            _loadMonth(prev);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                          onNextMonth: () {
                            final next = DateTime(
                              _focusedDay.year,
                              _focusedDay.month + 1,
                              1,
                            );
                            setState(() => _focusedDay = next);
                            _loadMonth(next);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                        ),
                        TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: DateTime(2100, 12, 31),
                          focusedDay: _focusedDay,
                          headerVisible: false,
                          sixWeekMonthsEnforced: true,
                          rowHeight: 48,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          selectedDayPredicate: (d) =>
                              _selectedDay != null &&
                              d.year == _selectedDay!.year &&
                              d.month == _selectedDay!.month &&
                              d.day == _selectedDay!.day,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = dateKey(selectedDay);
                              _focusedDay = focusedDay;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _sheetVisible = true;
                              });
                              _recalculateSheetFractions();
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay);
                            _loadMonth(focusedDay);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_sheetVisible) _recalculateSheetFractions();
                            });
                          },
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                          ),
                          daysOfWeekHeight: 30,
                          calendarBuilders: CalendarBuilders(
                            dowBuilder: (context, day) {
                              const labels = [
                                '일',
                                '월',
                                '화',
                                '수',
                                '목',
                                '금',
                                '토',
                              ];
                              final label = labels[day.weekday % 7];
                              return Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                            selectedBuilder: (context, day, focusedDay) {
                              // iOS(리뷰 m6, §6 W7): 선택된 날짜는 완료 여부와
                              // 무관하게 항상 브랜드 컬러로 꽉 찬 원이다.
                              if (cupertino) {
                                return FilledDay(
                                  text: day.day.toString(),
                                  bg: primaryBlue,
                                  fg: Colors.white,
                                );
                              }
                              // Android: 기존 로직 그대로(모두 완료면 꽉 찬
                              // 파란 원, 아니면 테두리만) — 외형 변경 없음.
                              final key = dateKey(day);
                              final total = _totalByDay[key] ?? 0;
                              final done = _doneByDay[key] ?? 0;
                              if (total > 0 && done >= total) {
                                return FilledDay(
                                  text: day.day.toString(),
                                  bg: primaryBlue,
                                  fg: Colors.white,
                                );
                              }
                              return OutlinedDay(
                                text: day.day.toString(),
                                color: primaryBlue,
                              );
                            },
                            defaultBuilder: (context, day, focusedDay) {
                              return _buildBaseDay(day, primaryBlue);
                            },
                            // iOS 전용: "오늘"을 항상 브랜드 컬러 원(채움/
                            // 아웃라인)으로 표시한다(§6 W7). Android는 이
                            // 빌더를 넘기지 않아 기존 TableCalendar 기본
                            // 스타일을 그대로 유지한다.
                            todayBuilder: isCupertino(context)
                                ? (context, day, focusedDay) =>
                                    _buildTodayDayIOS(day, primaryBlue)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 3, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: lightBlueBg),
                  ),
                ),
              ],
            ),
            // 비모달 드래그 시트: 초기엔 숨김, 날짜 선택 후 표시
            if (_sheetVisible)
              DraggableScrollableSheet(
                controller: _dragController,
                expand: false,
                snap: true,
                snapSizes: [(_minInitialSheetFraction ?? 0.43), 1.0],
                minChildSize: (_minInitialSheetFraction ?? 0.43),
                initialChildSize: (_minInitialSheetFraction ?? 0.43),
                maxChildSize: 1.0,
                builder: (context, scrollController) {
                  // iOS: 그래버 + 상단 곡률 xl(연속 곡률), 테두리 없이
                  // 불투명(§6 W7). Android는 기존 값(20, 사각 곡률 +
                  // 헤어라인 테두리)을 그대로 유지한다.
                  final sheetShape = cupertino
                      ? const RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                        )
                      : const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        );
                  return Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: sheetShape,
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        // 핸들바와 날짜 헤더 고정
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: Responsive.responsiveValue(context, 70),
                            child: Container(
                              height: Responsive.responsiveValue(context, 70),
                              color: Colors.white,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: Responsive.responsiveHeight(
                                      context,
                                      8,
                                    ),
                                  ),
                                  // handle bar(그래버). 리뷰 n3: iOS는
                                  // 고정 36×5(§4.3 시트 그래버 규격),
                                  // Android는 기존 64×5를 그대로 유지한다.
                                  Container(
                                    width: cupertino
                                        ? 36
                                        : Responsive.responsiveValue(context, 64),
                                    height: cupertino
                                        ? 5
                                        : Responsive.responsiveValue(context, 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(
                                        Responsive.responsiveValue(context, 3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.responsiveHeight(
                                      context,
                                      12,
                                    ),
                                  ),
                                  MedicationSheetHeader(
                                    selectedDay: _selectedDay,
                                    total: _selectedDay != null
                                        ? (_totalByDay[dateKey(
                                                _selectedDay!,
                                              )] ??
                                              0)
                                        : 0,
                                    done: _selectedDay != null
                                        ? (_doneByDay[dateKey(_selectedDay!)] ??
                                              0)
                                        : 0,
                                  ),
                                  SizedBox(
                                    height: Responsive.responsiveHeight(
                                      context,
                                      12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 주간 달력 고정 (패딩 포함)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: PinnedHeaderDelegate(
                            height: Responsive.responsiveValue(context, 85),
                            child: Container(
                              height: Responsive.responsiveValue(context, 85),
                              color: Colors.white,
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: Responsive.responsivePadding(
                                      context,
                                      16,
                                      0,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: WeekStrip(
                                        selectedDay: _selectedDay,
                                        onDaySelected: (d) {
                                          setState(() {
                                            _selectedDay = dateKey(d);
                                            _focusedDay = d;
                                          });
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (_sheetVisible)
                                                  _recalculateSheetFractions();
                                              });
                                        },
                                        totalByDay: _totalByDay,
                                        doneByDay: _doneByDay,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.responsiveHeight(
                                      context,
                                      20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Builder(
                          builder: (_) {
                            final list = medsForSelected();
                            if (list.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    '선택한 날짜에 기록이 없습니다',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                      fontSize: Responsive.responsiveFontSize(
                                        context,
                                        14,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: Responsive.responsivePadding(
                                context,
                                16,
                                0,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  return MedicationTile(
                                    medication: list[index],
                                    selectedDay: _selectedDay,
                                  );
                                }, childCount: list.length),
                              ),
                            );
                          },
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: Responsive.responsiveHeight(context, 20),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 3),
      ),
    );
  }
}
