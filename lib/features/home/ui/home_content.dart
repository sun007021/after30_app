import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/calendar/data/history_service.dart';
import 'package:after30/features/common/topbar.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dotted_border/dotted_border.dart';

class HomeContent extends StatefulWidget {
  final User? user;

  const HomeContent({super.key, required this.user});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final Set<String> _completedDoseKeys = <String>{};

  DateTime _selectedDate = DateTime.now();
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDosesForDate(_selectedDate);
    _loadCompletedFromServer(_selectedDate);
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

  Future<void> _loadCompletedFromServer(DateTime date) async {
    try {
      final hs = HistoryService();
      final ymd = _yyyymmdd(date);
      final list = await hs.getUserHistories(
        startDate:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        endDate:
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
      final next = <String>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (status == 'taken') {
          final scheduleId = (m['schedule_id'] as num?)?.toInt();
          final timeStr = (m['scheduled_time'] ?? '00:00').toString();
          if (scheduleId != null) {
            next.add('${scheduleId}_${ymd}_$timeStr');
          }
        }
      }
      if (mounted) {
        setState(() {
          _completedDoseKeys
            ..clear()
            ..addAll(next);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _completedDoseKeys.clear();
        });
      }
    }
  }

  Future<void> _goToRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineRegisterPage()),
    );
    await _loadDosesForDate(_selectedDate);
    await _loadCompletedFromServer(_selectedDate);
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
    _loadDosesForDate(_selectedDate);
    _loadCompletedFromServer(_selectedDate);
  }

  String _formatKoreanDate(DateTime d) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = days[(d.weekday + 6) % 7];
    return '${d.month}/${d.day} ($weekday)';
  }

  String _yyyymmdd(DateTime d) {
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  String _formatKoreanTime(String hhmmss) {
    final parts = hhmmss.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '알람 $hh:$mm';
  }

  // 시간 유틸 제거됨 (서버 문자열 사용)
  String _formatHHmm(DateTime dt) {
    // 서버에서 오는 완료 시간이 UTC 기준이므로 KST(+9)로 보정 후 24시간제로 변환
    final adjusted = dt.add(const Duration(hours: 9));
    final hh = adjusted.hour.toString().padLeft(2, '0');
    final mm = adjusted.minute.toString().padLeft(2, '0');
    return '알람 $hh:$mm';
  }

  Future<void> _markCompleted(String doseKey) async {
    try {
      final parts = doseKey.split('_');
      if (parts.length >= 3) {
        final scheduleId = int.tryParse(parts[0]);
        final dateStr =
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final timeStr = parts[2];
        if (scheduleId != null) {
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
          await _loadCompletedFromServer(_selectedDate);
        }
      }
    } catch (_) {}
  }

  Future<void> _markUncompleted(String doseKey) async {
    try {
      final parts = doseKey.split('_');
      if (parts.length >= 3) {
        final scheduleId = int.tryParse(parts[0]);
        final dateStr =
            '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final timeStr = parts[2];
        if (scheduleId != null) {
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
          await _loadCompletedFromServer(_selectedDate);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<Medication> dayMeds = [..._medications]
      ..sort((a, b) => a.time.compareTo(b.time));
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 상단 영역 하늘색 배경
          Container(height: 220, color: const Color(0xFFEBF0FF)),
          // 본문 레이어
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 본문 스크롤
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단 흰 배경 바 + 알람 아이콘
                        const AlarmTopBar(),
                        // 상단 파란 배경 스트립 + 타이틀
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(
                            left: 22,
                            right: 16,
                            bottom: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const PageTitle(
                            title: '나의 복약 체크 리스트',
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                              24,
                              24,
                              24,
                              24 + bottomSafe,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () => _changeDate(-1),
                                      icon: SvgPicture.asset(
                                        'assets/images/chevron_left.svg',
                                        width: 8,
                                        height: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatKoreanDate(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _changeDate(1),
                                      icon: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..scale(-1.0, 1.0, 1.0),
                                        child: SvgPicture.asset(
                                          'assets/images/chevron_left.svg',
                                          width: 8,
                                          height: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_isLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (dayMeds.isEmpty)
                                  _EmptyMedicineSection(onAdd: _goToRegister)
                                else ...[
                                  ...dayMeds.map((m) {
                                    final isCompleted = m.status == 'taken';
                                    final doseKey =
                                        '${m.scheduleId ?? m.id}_${_yyyymmdd(_selectedDate)}_${m.time}';
                                    final timeLabel = _formatKoreanTime(m.time);
                                    final Color primaryBlue = const Color(
                                      0xFF235DFF,
                                    );
                                    final Color lightBlueBg = const Color(
                                      0xFFE6F0FF,
                                    );
                                    final Color lightGreyBg = const Color(
                                      0xFFFCFCFC,
                                    );
                                    final Color greyBorder = const Color(
                                      0xFFD9D9D9,
                                    );
                                    final Color dangerRed = const Color(
                                      0xFFE50000,
                                    );
                                    final Color lightRedBg = const Color(
                                      0xFFFFE8EA,
                                    );
                                    final Color lightRedBorder = const Color(
                                      0xFFED9793,
                                    );

                                    bool isOverdue = false;
                                    try {
                                      final now = DateTime.now();
                                      final isSameDay =
                                          _selectedDate.year == now.year &&
                                          _selectedDate.month == now.month &&
                                          _selectedDate.day == now.day;
                                      if (!isCompleted && isSameDay) {
                                        final parts = m.time.split(':');
                                        final hh =
                                            int.tryParse(
                                              parts.isNotEmpty ? parts[0] : '0',
                                            ) ??
                                            0;
                                        final mm =
                                            int.tryParse(
                                              parts.length > 1 ? parts[1] : '0',
                                            ) ??
                                            0;
                                        final isPast =
                                            hh < now.hour ||
                                            (hh == now.hour &&
                                                mm <= now.minute);
                                        isOverdue = isPast;
                                      }
                                    } catch (_) {}
                                    final nowDate = DateTime.now();
                                    final bool isToday =
                                        _selectedDate.year == nowDate.year &&
                                        _selectedDate.month == nowDate.month &&
                                        _selectedDate.day == nowDate.day;
                                    final DateTime todayOnly = DateTime(
                                      nowDate.year,
                                      nowDate.month,
                                      nowDate.day,
                                    );
                                    final DateTime selectedOnly = DateTime(
                                      _selectedDate.year,
                                      _selectedDate.month,
                                      _selectedDate.day,
                                    );
                                    final bool isPastDay = selectedOnly
                                        .isBefore(todayOnly);
                                    final bool isMissed =
                                        !isCompleted &&
                                        (isPastDay || isOverdue);

                                    return Center(
                                      child: SizedBox(
                                        width: 320,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? lightBlueBg
                                                : (isMissed
                                                      ? lightRedBg
                                                      : lightGreyBg),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isCompleted
                                                  ? primaryBlue
                                                  : (isMissed
                                                        ? lightRedBorder
                                                        : greyBorder),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              20,
                                              14,
                                              20,
                                              3,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (isCompleted)
                                                      SvgPicture.asset(
                                                        'assets/images/check.svg',
                                                        width: 20,
                                                        height: 20,
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                              primaryBlue,
                                                              BlendMode.srcIn,
                                                            ),
                                                      )
                                                    else
                                                      Icon(
                                                        isMissed
                                                            ? Icons
                                                                  .error_outline
                                                            : Icons.access_time,
                                                        color: isMissed
                                                            ? dangerRed
                                                            : Colors.black38,
                                                        size: 25,
                                                      ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isCompleted
                                                          ? '복용 완료'
                                                          : (isMissed
                                                                ? '미복용'
                                                                : '복약 예정'),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isCompleted
                                                            ? const Color(
                                                                0xFF0034C4,
                                                              )
                                                            : (isMissed
                                                                  ? dangerRed
                                                                  : Colors
                                                                        .black45),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (isCompleted &&
                                                        m.takenAt != null)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                    0.04,
                                                                  ),
                                                              blurRadius: 4,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    1,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          _formatHHmm(
                                                            m.takenAt!,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: const Color(
                                                              0xFF0034C4,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    const Spacer(),
                                                    if (isCompleted || isMissed)
                                                      Builder(
                                                        builder: (buttonCtx) => GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTapDown:
                                                              (
                                                                TapDownDetails
                                                                details,
                                                              ) async {
                                                                try {
                                                                  final RenderBox
                                                                  buttonBox =
                                                                      buttonCtx
                                                                              .findRenderObject()
                                                                          as RenderBox;
                                                                  final RenderBox
                                                                  overlay =
                                                                      Overlay.of(
                                                                            buttonCtx,
                                                                          ).context.findRenderObject()
                                                                          as RenderBox;
                                                                  final Offset
                                                                  topLeft = buttonBox
                                                                      .localToGlobal(
                                                                        Offset
                                                                            .zero,
                                                                        ancestor:
                                                                            overlay,
                                                                      );
                                                                  final Offset
                                                                  bottomRight = buttonBox.localToGlobal(
                                                                    buttonBox
                                                                        .size
                                                                        .bottomRight(
                                                                          Offset
                                                                              .zero,
                                                                        ),
                                                                    ancestor:
                                                                        overlay,
                                                                  );
                                                                  final position = RelativeRect.fromLTRB(
                                                                    topLeft.dx,
                                                                    topLeft.dy,
                                                                    overlay
                                                                            .size
                                                                            .width -
                                                                        bottomRight
                                                                            .dx,
                                                                    overlay
                                                                            .size
                                                                            .height -
                                                                        bottomRight
                                                                            .dy,
                                                                  );
                                                                  final List<
                                                                    PopupMenuEntry<
                                                                      String
                                                                    >
                                                                  >
                                                                  items =
                                                                      isCompleted
                                                                      ? const [
                                                                          PopupMenuItem<
                                                                            String
                                                                          >(
                                                                            value:
                                                                                'undo',
                                                                            child: Text(
                                                                              '복약 미완료',
                                                                            ),
                                                                          ),
                                                                        ]
                                                                      : const [
                                                                          PopupMenuItem<
                                                                            String
                                                                          >(
                                                                            value:
                                                                                'complete',
                                                                            child: Text(
                                                                              '복용 완료',
                                                                            ),
                                                                          ),
                                                                        ];
                                                                  final selected =
                                                                      await showMenu<
                                                                        String
                                                                      >(
                                                                        context:
                                                                            buttonCtx,
                                                                        position:
                                                                            position,
                                                                        color: Colors
                                                                            .white,
                                                                        items:
                                                                            items,
                                                                      );
                                                                  if (selected ==
                                                                      'complete') {
                                                                    await _markCompleted(
                                                                      doseKey,
                                                                    );
                                                                  } else if (selected ==
                                                                      'undo') {
                                                                    await _markUncompleted(
                                                                      doseKey,
                                                                    );
                                                                  }
                                                                } catch (_) {}
                                                              },
                                                          child: const SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: Icon(
                                                              Icons.more_vert,
                                                              size: 24,
                                                              color: Colors
                                                                  .black26,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            m.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  bottom: 12,
                                                                ),
                                                            child: Text(
                                                              timeLabel,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (!isCompleted &&
                                                        isToday &&
                                                        !isOverdue)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 8,
                                                            ),
                                                        child: ElevatedButton(
                                                          onPressed: () =>
                                                              _markCompleted(
                                                                doseKey,
                                                              ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                primaryBlue,
                                                            foregroundColor:
                                                                Colors.white,
                                                            elevation: 0,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 5,
                                                                ),
                                                            minimumSize:
                                                                const Size(
                                                                  0,
                                                                  20,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            '복용 완료',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                  _AddMedicineTile(onAdd: _goToRegister),
                                  const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}

class _AddMedicineTile extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddMedicineTile({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAdd,
        child: DottedBorder(
          color: const Color(0xFFBDBDBD),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Column(
              children: const [
                Icon(Icons.add, color: Colors.black54),
                SizedBox(height: 4),
                Text('추가하기', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMedicineSection extends StatelessWidget {
  final VoidCallback onAdd;
  final String? title;
  const _EmptyMedicineSection({required this.onAdd, this.title});

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF235DFF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SvgPicture.asset(
            'assets/images/medi_icon.svg',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 50),
          Text(
            title ?? '등록된 약이 없어요',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '약 등록하기',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                Icon(Icons.add, size: 18, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
