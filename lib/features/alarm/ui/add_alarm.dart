import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/schedule_service.dart';
import 'package:after30/features/alarm/ui/alarm_permission_gate.dart';
import 'package:after30/features/alarm/ui/widgets/budget_warning_listener.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/utils/responsive.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';

class MedicineRegisterPage extends StatefulWidget {
  final MedicineAlarm? initialAlarm;

  /// 테스트/프리뷰용 주입 지점. 지정하지 않으면 실제 서비스를 쓴다.
  final ScheduleService? scheduleService;
  final AlarmService? alarmService;
  final AlarmPermissionGate? permissionGate;
  final Stream<String>? budgetWarnings;

  const MedicineRegisterPage({
    super.key,
    this.initialAlarm,
    this.scheduleService,
    this.alarmService,
    this.permissionGate,
    this.budgetWarnings,
  });

  @override
  State<MedicineRegisterPage> createState() => _MedicineRegisterPageState();
}

class _MedicineRegisterPageState extends State<MedicineRegisterPage> {
  late final TextEditingController _medicineController;
  late List<String> _selectedDays;
  final List<String> _allDays = ['월', '화', '수', '목', '금', '토', '일'];
  late List<TimeOfDay> _times;
  late bool _allDaysSelected;
  bool _nfcEnabled = false;
  bool _isLoading = false;

  /// 제출 처리 중 여부. 확인 다이얼로그가 떠 있는 동안에도 켜 둬서 "등록하기"를
  /// 연타해도 확인창/서버 호출이 중복되지 않게 한다.
  bool _busy = false;

  /// 이 화면에서 이미 서버에 만든 스케줄 id. 기기 예약이 실패해 같은 화면에서
  /// 다시 시도할 때 서버 스케줄이 또 만들어지지 않도록 기억한다.
  int? _createdScheduleId;

  int get _currentStep {
    final hasName = _medicineController.text.trim().isNotEmpty;
    final hasDays = _selectedDays.isNotEmpty;
    if (!hasName) return 1;
    if (!hasDays) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    final alarm = widget.initialAlarm;
    _medicineController = TextEditingController(text: alarm?.name ?? '');
    // 원본 알람 객체를 변형하지 않도록 복사한다(저장 전에 뒤로 가도 목록 카드가
    // 바뀌면 안 된다).
    _selectedDays = List<String>.of(alarm?.days ?? const []);
    _times = alarm != null
        ? List<TimeOfDay>.from(alarm.times)
        : [TimeOfDay(hour: 8, minute: 0)];
    _allDaysSelected = _selectedDays.length == 7;
    if (alarm != null) {
      _nfcEnabled = alarm.nfcEnabled;
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    super.dispose();
  }

  bool get _isMedicineEmpty => _medicineController.text.trim().isEmpty;

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _allDaysSelected = _selectedDays.length == 7;
    });
  }

  void _toggleAllDays() {
    setState(() {
      if (_allDaysSelected) {
        _selectedDays.clear();
        _allDaysSelected = false;
      } else {
        _selectedDays.clear();
        _selectedDays.addAll(_allDays);
        _allDaysSelected = true;
      }
    });
  }

  void _addTime() {
    // 마지막 시간 + 1시간을 기본값으로 제안해 같은 시각이 중복 추가되는 것을 막는다.
    TimeOfDay candidate;
    if (_times.isEmpty) {
      candidate = const TimeOfDay(hour: 8, minute: 0);
    } else {
      final lastMinutes = _times
          .map((t) => t.hour * 60 + t.minute)
          .reduce((a, b) => a > b ? a : b);
      final nextMinutes = (lastMinutes + 60) % (24 * 60);
      candidate = TimeOfDay(hour: nextMinutes ~/ 60, minute: nextMinutes % 60);
    }
    final duplicate = _times.any(
      (t) => t.hour == candidate.hour && t.minute == candidate.minute,
    );
    if (duplicate) {
      DoubleCheckDialog.showSingle(
        context: context,
        title: '안내',
        message: '이미 같은 시간이 등록되어 있습니다. 시간을 눌러 변경해주세요.',
      );
      return;
    }
    setState(() {
      _times.add(candidate);
      _times.sort(
        (a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute),
      );
    });
  }

  void _showMinimumTimeNotice() {
    DoubleCheckDialog.showSingle(
      context: context,
      title: '안내',
      message: '복용 시간은 최소 1개 이상 입력해야 합니다.',
    );
  }

  void _removeTimeAt(int idx) {
    if (_times.length == 1) {
      _showMinimumTimeNotice();
      return;
    }
    setState(() => _times.removeAt(idx));
  }

  // 등록/수정 직전에 중복 시간을 제거하고 정렬해 서버 저장값과 로컬 스케줄이
  // 어긋나지 않도록 한다(서버는 중복 시간을 제거해서 저장함).
  List<TimeOfDay> _dedupeAndSortTimes(List<TimeOfDay> input) {
    final seen = <int>{};
    final result = <TimeOfDay>[];
    for (final t in input) {
      final key = t.hour * 60 + t.minute;
      if (seen.add(key)) {
        result.add(t);
      }
    }
    result.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
    return result;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hh = tod.hour.toString().padLeft(2, '0');
    final mm = tod.minute.toString().padLeft(2, '0');
    return '알람 $hh:$mm';
  }

  Future<void> _pickTime(int idx) async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _times[idx],
    );
    if (picked != null && mounted) {
      setState(() {
        _times[idx] = picked;
        _times.sort(
          (a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute),
        );
      });
    }
  }

  void _medicineListener() {
    setState(() {});
  }

  AlarmPermissionGate get _gate =>
      widget.permissionGate ?? const SystemAlarmPermissionGate();

  /// 설정에서 알림이 꺼진 상태(거부)였는지. 저장 후 안내 방식을 가른다.
  bool _notificationsDenied = false;

  /// 신규 등록 직전에 **실제 시스템 권한 상태**를 확인한다(iOS).
  /// - 허용됨: 설명 없이 통과(AlarmKit 권한만 미결정이면 이어서 요청).
  /// - 미결정: 사전 설명 알럿 → 시스템 권한 요청.
  /// - 거부됨: 시스템 프롬프트를 다시 띄울 수 없으므로 저장 후 안내한다.
  /// 반환값은 "알림이 울릴 수 있는 상태인가"이며, false여도 등록은 그대로
  /// 진행한다. Android는 로그인 직후 이미 요청했고 기존 동작을 유지한다.
  Future<bool> _ensureNotificationPermission() async {
    if (!isCupertino(context)) return true;
    try {
      final status = await _gate.status();
      switch (status) {
        case NotificationAuthorizationStatus.authorized:
        case NotificationAuthorizationStatus.provisional:
        case NotificationAuthorizationStatus.ephemeral:
          await _gate.ensureAlarmKit();
          return true;
        case NotificationAuthorizationStatus.denied:
          _notificationsDenied = true;
          return false;
        case NotificationAuthorizationStatus.notDetermined:
          if (!mounted) return true;
          return await _gate.requestWithRationale(context);
      }
    } catch (_) {
      return true;
    }
  }

  /// 알림이 꺼져 있어 알람이 울리지 않을 때의 안내. 설정에서 거부한 경우에는
  /// 설정 앱을 바로 열 수 있게 확인창을 먼저 보여준다.
  Future<void> _warnNotificationsOff() async {
    if (_notificationsDenied) {
      final openSettings = await showAppConfirm(
        context: context,
        title: '알림이 꺼져 있어요',
        message: '알림 권한이 꺼져 있으면 복약 알람이 울리지 않아요. 설정에서 알림을 허용해주세요.',
        cancelLabel: '나중에',
        confirmLabel: '설정 열기',
      );
      if (openSettings) {
        await _gate.openSettings();
        return;
      }
      if (!mounted) return;
    }
    AppToast.show(
      context,
      '알림 권한이 꺼져 있어 허용하기 전까지 알람이 울리지 않아요.',
      type: AppToastType.error,
    );
  }

  Future<void> _showError(String title, String message) {
    if (isCupertino(context)) {
      return showAppAlert(context: context, title: title, message: message);
    }
    // Android는 기존 Material AlertDialog 외형을 그대로 유지한다.
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    _busy = true;
    try {
      await _submitInner();
    } finally {
      _busy = false;
    }
  }

  Future<void> _submitInner() async {
    final name = _medicineController.text.trim();
    final times = _dedupeAndSortTimes(_times);
    final hasMissing = name.isEmpty || _selectedDays.isEmpty || times.isEmpty;
    if (hasMissing) {
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '아직 입력되지 않은 정보가 있어요.',
        message: '복약 시간이나 약 이름을 입력해야 정확한 알림을 드릴 수 있어요.',
      );
      return;
    }
    if (name.length > 255) {
      await DoubleCheckDialog.showSingle(
        context: context,
        title: '안내',
        message: '약 이름은 1~255자 사이여야 합니다.',
      );
      return;
    }
    final isEdit = widget.initialAlarm != null;
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: isEdit ? '수정한 내용을 저장할까요?' : '약을 등록하시겠습니까?',
      message: isEdit
          ? '변경된 복약 시간은 다음 알림부터 바로 적용됩니다.'
          : '입력하신 시간에 맞춰 잊지 않도록 알림을 보내드릴게요.',
      confirmLabel: isEdit ? '저장' : '등록',
      cancelLabel: '취소',
    );
    if (!confirmed || !mounted) return;

    // 신규 등록에서만 권한 상태를 확인한다(이미 서버에 만든 뒤 재시도할 때와
    // 수정 화면은 제외).
    final canNotify = (isEdit || _createdScheduleId != null)
        ? true
        : await _ensureNotificationPermission();
    if (!mounted) return;

    late final MedicineAlarm alarm;
    setState(() {
      _isLoading = true;
    });

    try {
      final scheduleService = widget.scheduleService ?? ScheduleService();
      final now = DateTime.now();
      final startDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStrings = times
          .map(
            (t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          )
          .toList();
      const dayEnumMap = {
        '월': 'MON',
        '화': 'TUE',
        '수': 'WED',
        '목': 'THU',
        '금': 'FRI',
        '토': 'SAT',
        '일': 'SUN',
      };
      final repeatDays = _selectedDays
          .map((d) => dayEnumMap[d])
          .whereType<String>()
          .toList();
      final body = {
        'medication_name': name,
        'times': timeStrings,
        'repeat_days': repeatDays,
        if (widget.initialAlarm == null && _createdScheduleId == null)
          'start_date': startDate,
      };
      if (_createdScheduleId != null) {
        // 앞선 시도에서 서버 스케줄은 이미 만들어졌다. 기기 예약만 다시 하되,
        // 그 사이 입력이 바뀌었을 수 있으니 서버 내용은 갱신한다.
        final scheduleId = _createdScheduleId!;
        await scheduleService.updateSchedule(scheduleId, body);
        alarm = MedicineAlarm(
          id: scheduleId.toString(),
          name: name,
          times: times,
          days: List.from(_selectedDays),
          everyDay: _selectedDays.length == 7,
          nfcEnabled: _nfcEnabled,
        );
      } else if (widget.initialAlarm == null) {
        final created = await scheduleService.createSchedule(body);
        final createdMap = created as Map<String, dynamic>;
        final scheduleId = (createdMap['id'] as num).toInt();
        _createdScheduleId = scheduleId;
        final everyDay = _selectedDays.length == 7;
        alarm = MedicineAlarm(
          id: scheduleId.toString(),
          name: name,
          times: times,
          days: List.from(_selectedDays),
          everyDay: everyDay,
          nfcEnabled: _nfcEnabled,
        );
      } else {
        final scheduleId = int.tryParse(widget.initialAlarm!.id);
        if (scheduleId == null) {
          throw Exception('기존 알람 ID가 유효하지 않습니다.');
        }
        await scheduleService.updateSchedule(scheduleId, body);
        final everyDay = _selectedDays.length == 7;
        alarm = MedicineAlarm(
          id: widget.initialAlarm!.id,
          name: name,
          times: times,
          days: List.from(_selectedDays),
          everyDay: everyDay,
          nfcEnabled: _nfcEnabled,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _showError('오류', '스케줄 생성에 실패했습니다. 다시 시도해주세요.\n$e');
      }
      return;
    }

    final alarmService = widget.alarmService ?? AlarmService();
    final success = await alarmService.scheduleAlarm(alarm);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      AppHaptics.success(context);
      if (!canNotify) {
        await _warnNotificationsOff();
        if (!mounted) return;
      }
      Navigator.pop(context, alarm);
    } else {
      await _showError('안내', '알람 등록에 실패했습니다. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    _medicineController.removeListener(_medicineListener);
    _medicineController.addListener(_medicineListener);

    return BudgetWarningListener(
      warnings: widget.budgetWarnings,
      child: isCupertino(context)
          ? _buildCupertino(context)
          : _buildMaterial(context),
    );
  }

  // ---------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: AppTypography.title.copyWith(fontSize: 20)),
  );

  Widget _buildCupertino(BuildContext context) {
    final isEdit = widget.initialAlarm != null;
    final nameLength = _medicineController.text.length;
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppNavBar(
        title: isEdit ? '약 수정' : '약 등록',
        backgroundColor: AppColors.groupedBackground,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepHeader(currentStep: _currentStep),
                  const SizedBox(height: 12),
                  _sectionTitle('1. 어떤 약을 드시나요?'),
                  AppTextField(
                    controller: _medicineController,
                    placeholder: '약 이름을 입력 해주세요',
                    maxLength: 255,
                    textInputAction: TextInputAction.done,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$nameLength/255',
                        key: const ValueKey('nameCounter'),
                        style: AppTypography.footnote,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('2. 복용 날짜를 선택해주세요')),
                      _everyDayChip(),
                    ],
                  ),
                  _dayToggles(context, AppColors.primary),
                  const SizedBox(height: 32),
                  _sectionTitle('3. 복용 시간을 알려주세요'),
                  AppGroupedSection(
                    children: [
                      for (var i = 0; i < _times.length; i++)
                        AppSwipeActions(
                          key: ValueKey(_timeKey(i)),
                          itemKey: ValueKey(_timeKey(i)),
                          // 최소 1개 규칙: 마지막 한 개는 삭제 확인 전에 막는다.
                          confirmDismiss: () async {
                            if (_times.length == 1) {
                              _showMinimumTimeNotice();
                              return false;
                            }
                            return true;
                          },
                          onDelete: () => _removeTimeAt(i),
                          child: AppListTile(
                            title: '알람',
                            trailing: Text(
                              _formatHHmm(_times[i]),
                              style: const TextStyle(
                                fontSize: 17,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _pickTime(i),
                          ),
                        ),
                      AppListTile(
                        title: '시간 추가',
                        leading: const Icon(
                          CupertinoIcons.add_circled_solid,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        leadingWidth: 22,
                        onTap: _addTime,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 키보드가 올라오면 Scaffold가 body를 줄이므로 CTA가 키보드 위에 남는다.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: AppButton(
                label: '등록하기',
                loading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 시간 행의 안정적인 키: 시각 값 + 같은 시각 중 몇 번째인지. 목록이
  /// 정렬/삭제로 재배열돼도 같은 시각의 행은 같은 키를 유지한다.
  String _timeKey(int index) {
    final t = _times[index];
    var occurrence = 0;
    for (var i = 0; i < index; i++) {
      if (_times[i].hour == t.hour && _times[i].minute == t.minute) occurrence++;
    }
    return 'time_${t.hour}_${t.minute}_$occurrence';
  }

  String _formatHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// iOS의 "매일" 토글 칩(Android의 "전체선택" 체크박스 대체).
  Widget _everyDayChip() {
    final on = _allDaysSelected;
    return Semantics(
      button: true,
      selected: on,
      label: '매일',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('everyDayChip'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection(context);
          _toggleAllDays();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.capsule),
            ),
            child: Text(
              '매일',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 요일 원형 토글(44pt). 두 플랫폼 공통이며 색상만 다르다.
  Widget _dayToggles(BuildContext context, Color accent) {
    return Wrap(
      spacing: Responsive.responsiveValue(context, 10),
      runSpacing: Responsive.responsiveValue(context, 8),
      alignment: WrapAlignment.start,
      children: _allDays.map((day) {
        final selected = _selectedDays.contains(day);
        return GestureDetector(
          onTap: () {
            AppHaptics.selection(context);
            _toggleDay(day);
          },
          child: Container(
            width: Responsive.responsiveValue(context, 44),
            height: Responsive.responsiveValue(context, 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accent : Colors.white,
              border: Border.all(color: accent, width: 2),
              shape: BoxShape.circle,
            ),
            child: Text(
              day,
              style: TextStyle(
                color: selected ? Colors.white : accent,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: Responsive.responsiveFontSize(context, 16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------
  // Android(기존 외형/동작 그대로)
  // ---------------------------------------------------------------------

  Widget _buildMaterial(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: Responsive.responsivePadding(context, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  StepHeader(currentStep: _currentStep),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '1. 어떤 약을 드시나요?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _medicineController,
                    decoration: InputDecoration(
                      hintText: '약 이름을 입력 해주세요',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: _isMedicineEmpty
                          ? Colors.grey[200]
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 55),
                  const Text(
                    '2. 복용 날짜를 선택해주세요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Spacer(),
                      const Text('전체선택'),
                      Checkbox(
                        value: _allDaysSelected,
                        onChanged: (_) => _toggleAllDays(),
                        activeColor: const Color(0xFF235DFF),
                      ),
                    ],
                  ),
                  _dayToggles(context, const Color(0xFF235DFF)),
                  const SizedBox(height: 45),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '3. 복용 시간을 알려주세요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.black),
                        onPressed: _addTime,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ..._times.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(idx),
                              child: AbsorbPointer(
                                child: TextField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                    text: _formatTimeOfDay(t),
                                  ),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Color(0xFF235DFF),
                            ),
                            tooltip: '이 시간 삭제',
                            onPressed: () => _removeTimeAt(idx),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF235DFF),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '등록하기',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
