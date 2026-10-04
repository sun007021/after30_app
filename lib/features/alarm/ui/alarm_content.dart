import 'dart:async';

import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/ui/add_alarm.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/ui/widgets/alarm_card.dart';
import 'package:after30/features/alarm/ui/widgets/budget_warning_listener.dart';
import 'package:after30/features/alarm/ui/widgets/empty_alarm_section.dart';
import 'package:after30/utils/responsive.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';

class AlarmContent extends StatefulWidget {
  const AlarmContent({
    super.key,
    this.scheduleService,
    this.alarmService,
    this.budgetWarnings,
  });

  /// 테스트/프리뷰용 주입 지점. 지정하지 않으면 실제 서비스를 쓴다.
  final ScheduleService? scheduleService;
  final AlarmService? alarmService;
  final Stream<String>? budgetWarnings;

  @override
  State<AlarmContent> createState() => AlarmContentState();
}

/// `AlarmPage`가 `GlobalKey<AlarmContentState>`로 접근해 탭 재활성화 때
/// [onTabActivated]를 호출할 수 있도록 공개 타입으로 둔다. AppShell은 탭을
/// 살려두므로 [initState]는 최초 방문 때 한 번만 실행되고, 이후 갱신은 이
/// 훅으로만 가능하다.
class AlarmContentState extends State<AlarmContent> {
  final List<MedicineAlarm> _alarms = [];
  late final AlarmService _alarmService = widget.alarmService ?? AlarmService();
  late final ScheduleService _scheduleService =
      widget.scheduleService ?? ScheduleService();
  bool _isLoading = true;

  /// 최초 로딩이 한 번이라도 끝났는지. 끝나기 전의 탭 활성화 알림은 이미 진행
  /// 중인 최초 로딩과 중복이므로 무시한다.
  bool _initialLoadDone = false;

  /// 응답 경쟁 방지용 요청 일련번호. 가장 마지막에 시작한 요청의 응답만
  /// 화면에 반영한다(느린 이전 응답이 새 응답을 덮어쓰지 않게).
  int _loadSeq = 0;
  bool _syncing = false;

  /// 동기화 도중 새로 도착한 목록. 현재 동기화가 끝나면 한 번 더 처리한다.
  List<MedicineAlarm>? _pendingSync;

  /// 삭제/토글이 진행 중인 알람 키('del:id', 'tog:id'). 같은 알람에 대한
  /// 중복 요청을 막는다.
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  /// 탭이 (재선택/앱 재개 포함) 다시 활성화됐을 때 목록을 조용히 다시
  /// 불러온다. 최초 방문 로딩이 아직 끝나지 않았으면 중복 요청을 하지
  /// 않는다.
  Future<void> onTabActivated() async {
    if (!_initialLoadDone) return;
    await _loadAlarms(showSpinner: false);
  }

  Future<void> _loadAlarms({bool showSpinner = true}) async {
    final seq = ++_loadSeq;
    if (showSpinner) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final schedules = await _scheduleService.getSchedules(
        includeInactive: true,
      );
      // 더 최근 요청이 시작됐거나 화면이 사라졌다면 이 응답은 버린다.
      if (!mounted || seq != _loadSeq) return;
      final mapped = schedules.map<MedicineAlarm>((s) {
        final m = s as Map<String, dynamic>;
        final id = (m['id'] as num).toInt().toString();
        final name = (m['medication_name'] as String?) ?? '';
        final times = ((m['times'] as List?) ?? [])
            .map((t) => t.toString())
            .map((t) {
              final parts = t.split(':');
              final h = int.tryParse(parts[0]) ?? 8;
              final min = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
              return TimeOfDay(hour: h, minute: min);
            })
            .toList();
        final repeatDays = ((m['repeat_days'] as List?) ?? [])
            .map((d) => d.toString())
            .toList();
        const korMap = {
          'MON': '월',
          'TUE': '화',
          'WED': '수',
          'THU': '목',
          'FRI': '금',
          'SAT': '토',
          'SUN': '일',
        };
        final days = repeatDays.map((e) => korMap[e] ?? '월').toList();
        final everyDay = days.length == 7;
        final isActive = (m['is_active'] as bool?) ?? true;
        return MedicineAlarm(
          id: id,
          name: name,
          times: times,
          days: days,
          everyDay: everyDay,
          isActive: isActive,
          nfcEnabled: false,
        );
      }).toList();

      // 삭제 진행 중인 알람은 서버가 아직 지우기 전의 응답에 들어 있어도
      // 다시 보이지 않게 한다.
      final visible = mapped
          .where((a) => !_busyIds.contains('del:${a.id}'))
          .toList();
      setState(() {
        _alarms
          ..clear()
          ..addAll(visible);
        _isLoading = false;
        _initialLoadDone = true;
      });

      // 화면 표시는 먼저 마치고, 기기 예약 동기화는 뒤이어 수행(새 기기/재설치 후 복구용)
      unawaited(_syncDeviceSchedules(mapped));
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _isLoading = false;
        _initialLoadDone = true;
      });
      debugPrint('알람 불러오기 실패: $e');
    }
  }

  /// 기기 예약을 서버 목록에 맞춘다(새 기기/재설치 복구, 다른 기기에서의
  /// 삭제/비활성화 반영).
  ///
  /// iOS는 알람 하나를 예약할 때마다 64개 알림 예산 전체를 다시 계산하므로,
  /// 알람마다 `scheduleAlarm`을 부르지 않고 `syncFromServer`를 **한 번만**
  /// 호출한다(저장소 정리 + 전체 재예약 1회). 동기화는 한 번에 한 pass만
  /// 실행하고, 진행 중에 새 목록이 오면 끝난 뒤 최신 목록으로 한 번 더 돈다.
  /// Android는 알람별 예약이 가볍고 기존 동작이므로 누락된 알람만 하나씩
  /// 예약한다.
  Future<void> _syncDeviceSchedules(List<MedicineAlarm> alarms) async {
    if (_syncing) {
      _pendingSync = alarms;
      return;
    }
    _syncing = true;
    try {
      List<MedicineAlarm>? next = alarms;
      while (next != null && mounted) {
        _pendingSync = null;
        await _syncOnce(next);
        next = _pendingSync;
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce(List<MedicineAlarm> alarms) async {
    final batch = isCupertino(context);
    final active = alarms.where((a) => a.isActive).toList();
    final missing = <MedicineAlarm>[];
    for (final alarm in active) {
      try {
        if (!await _alarmService.hasScheduledNotifications(alarm.id)) {
          missing.add(alarm);
        }
      } catch (e) {
        debugPrint('알람 기기 동기화 확인 실패: id=${alarm.id}, error=$e');
      }
    }

    if (batch) {
      // 누락이 없어도 다른 기기에서 삭제/비활성화된 알람이 로컬 저장소에
      // 활성으로 남아 있으면 정리해야 한다.
      var stale = missing.isNotEmpty;
      if (!stale) {
        try {
          final stored = await _alarmService.getAlarms();
          final server = {for (final a in alarms) a.id: a.isActive};
          // 저장소와 서버의 활성 여부가 어긋나면(양방향) 맞춘다. 이 기기에서
          // 끈 알람을 다른 기기에서 다시 켜도 알림 id 키가 남아 있어
          // missing이 비므로 여기서 잡아야 한다(PR #36 최종 리뷰 Minor).
          stale =
              stored.any((s) => server.containsKey(s.id) ? server[s.id] != s.isActive : s.isActive) ||
              active.any((a) => !stored.any((s) => s.id == a.id));
        } catch (_) {}
      }
      if (stale) await _alarmService.syncFromServer(alarms);
      return;
    }
    for (final alarm in missing) {
      try {
        await _alarmService.scheduleAlarm(alarm);
      } catch (e) {
        debugPrint('알람 기기 동기화 실패: id=${alarm.id}, error=$e');
      }
    }
  }

  Future<void> _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineRegisterPage(
          scheduleService: widget.scheduleService,
          alarmService: widget.alarmService,
          budgetWarnings: widget.budgetWarnings,
        ),
      ),
    );
    if (result is MedicineAlarm && mounted) {
      await _loadAlarms(showSpinner: !isCupertino(context));
    }
  }

  Future<void> _goToEdit(MedicineAlarm alarm) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineRegisterPage(
          initialAlarm: alarm,
          scheduleService: widget.scheduleService,
          alarmService: widget.alarmService,
          budgetWarnings: widget.budgetWarnings,
        ),
      ),
    );
    if (result is MedicineAlarm && mounted) {
      await _loadAlarms(showSpinner: !isCupertino(context));
    }
  }

  Future<bool> _confirmDelete() {
    return showAppConfirm(
      context: context,
      title: '약 정보를 삭제하시겠습니까?',
      message: '삭제하면, 그동안 쌓인 복약 기록과 설정된 알림이 모두 사라져요.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
      // 빨간 destructive 스타일은 iOS 전용(Android는 기존 외형 유지).
      destructive: isCupertino(context),
    );
  }

  /// Android: 카드 메뉴의 "알람 삭제" → 확인 다이얼로그 → 삭제.
  Future<void> _deleteAlarm(MedicineAlarm alarm) async {
    if (_busyIds.contains('del:${alarm.id}')) return;
    final confirmed = await _confirmDelete();
    if (confirmed == true && mounted) {
      await _performDelete(alarm);
    }
  }

  /// 낙관적 삭제: 목록에서 먼저 지우고 서버 삭제 → 로컬 저장소/기기 예약
  /// 삭제 순으로 진행한다. 서버 삭제가 실패하면 원래 위치에 되돌린다.
  /// 확인은 호출자가 이미 받았다.
  Future<void> _performDelete(MedicineAlarm alarm) async {
    final key = 'del:${alarm.id}';
    if (!_busyIds.add(key)) return;
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      setState(() => _alarms.removeAt(index));
    }
    try {
      try {
        final scheduleId = int.tryParse(alarm.id);
        if (scheduleId != null) {
          await _scheduleService.deleteSchedule(scheduleId);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (!_alarms.any((a) => a.id == alarm.id)) {
              _alarms.insert(
                index < 0 ? 0 : index.clamp(0, _alarms.length),
                alarm,
              );
            }
          });
          AppToast.show(context, '서버 삭제 실패: $e', type: AppToastType.error);
        }
        return;
      }

      // 로컬 저장소와 기기 예약을 함께 지운다(저장소에 남으면 iOS 복귀/Android
      // 재시작 때 삭제된 알람이 다시 예약된다).
      try {
        await _alarmService.deleteAlarm(alarm.id);
      } catch (_) {}
    } finally {
      _busyIds.remove(key);
    }
    if (!mounted) return;
    await _loadAlarms(showSpinner: false);
  }

  Future<void> _toggleAlarm(MedicineAlarm target) async {
    final index = _alarms.indexWhere((a) => a.id == target.id);
    final busyKey = 'tog:${target.id}';
    if (index < 0 || _busyIds.contains(busyKey)) return;
    final alarm = _alarms[index];
    final newState = !alarm.isActive;

    // 확인 다이얼로그가 떠 있는 동안에도 같은 알람의 다른 토글을 막는다.
    _busyIds.add(busyKey);
    if (!newState) {
      final confirmed = await DoubleCheckDialog.show(
        context: context,
        title: '복용을 중단하시겠습니까?',
        message: '증상이 완화되어 복용을 멈추시는 건가요? 기록은 남기고 알림만 끌 수 있습니다.',
        cancelLabel: '아니요',
        confirmLabel: '중단하기',
      );
      if (!confirmed || !mounted) {
        _busyIds.remove(busyKey);
        return;
      }
    }

    void setActive(bool value) {
      final i = _alarms.indexWhere((a) => a.id == alarm.id);
      if (i < 0) return;
      setState(() {
        _alarms[i] = alarm.copyWith(isActive: value);
      });
    }

    setActive(newState);

    try {
      final scheduleId = int.tryParse(alarm.id);
      if (!newState) {
        if (scheduleId != null) {
          await _scheduleService.deactivateSchedule(scheduleId);
        }
        // 저장소의 isActive를 끄고 기기 예약을 취소한다.
        await _alarmService.toggleAlarm(alarm.id, false);
        await _alarmService.cancelAlarm(alarm.id);
        // 비활성화 날짜를 로컬에 기록 (달력 표시 컷오프 기준)
        try {
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now();
          final dateStr =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final userId = await UserStore.getCurrentUserId();
          final keyNs = userId != null
              ? 'inactive_since_${userId}_${alarm.id}'
              : 'inactive_since_${alarm.id}';
          await prefs.setString(keyNs, dateStr);
        } catch (_) {}
      } else {
        if (scheduleId != null) {
          await _scheduleService.activateSchedule(scheduleId);
        }
        // 켜진 상태로 저장/예약해야 한다(토글 전 객체는 isActive=false다).
        await _alarmService.scheduleAlarm(alarm.copyWith(isActive: true));
        // 재활성화 시 비활성 기준일 제거
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = await UserStore.getCurrentUserId();
          final keyNs = userId != null
              ? 'inactive_since_${userId}_${alarm.id}'
              : 'inactive_since_${alarm.id}';
          await prefs.remove(keyNs);
          // 레거시 키도 함께 정리
          await prefs.remove('inactive_since_${alarm.id}');
        } catch (_) {}
      }

      _busyIds.remove(busyKey);
      if (!mounted) return;
      await _loadAlarms(showSpinner: !isCupertino(context));
    } catch (e) {
      _busyIds.remove(busyKey);
      if (!mounted) return;
      setActive(!newState);
      AppToast.show(context, '상태 변경 동기화 실패: $e', type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BudgetWarningListener(
      warnings: widget.budgetWarnings,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cupertino = isCupertino(context);

    if (_isLoading) {
      return Expanded(
        child: Center(
          // Android는 기존 로더를 그대로 쓴다(AppActivityIndicator는 더 작다).
          child: cupertino
              ? const AppActivityIndicator()
              : const CircularProgressIndicator(),
        ),
      );
    }

    if (_alarms.isEmpty) {
      return EmptyAlarmSection(onAdd: _goToRegister);
    }

    return Expanded(
      child: SingleChildScrollView(
        padding: Responsive.responsivePadding(context, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: Responsive.responsiveHeight(context, 12)),
            ..._alarms.map((alarm) {
              return AlarmCard(
                key: ValueKey('alarm_${alarm.id}'),
                alarm: alarm,
                onToggle: () => _toggleAlarm(alarm),
                onEdit: () => _goToEdit(alarm),
                onDelete: () => _deleteAlarm(alarm),
                // iOS: 스와이프 삭제. 확인은 destructive 알럿으로 받는다.
                onSwipeDelete: () => _performDelete(alarm),
                confirmSwipeDelete: _confirmDelete,
              );
            }),
            SizedBox(height: Responsive.responsiveHeight(context, 40)),
            if (cupertino)
              AppButton(label: '약 등록하기', icon: const Icon(Icons.add, size: 20), onPressed: _goToRegister)
            else
              Center(
                child: Material(
                  borderRadius: BorderRadius.circular(
                    Responsive.responsiveValue(context, 4),
                  ),
                  color: Colors.transparent,
                  child: ElevatedButton(
                    onPressed: _goToRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF235DFF),
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        Responsive.responsiveValue(context, 180),
                        Responsive.responsiveValue(context, 32),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.responsiveValue(context, 4),
                        ),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      '약 등록하기  +',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 14),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: Responsive.responsiveHeight(context, 30)),
          ],
        ),
      ),
    );
  }
}
