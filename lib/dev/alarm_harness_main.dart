// 디버그 전용 알람 엔진 하네스(plan §6 W4 "검증" — Firebase/Kakao 초기화
// 없이 스케줄러 선택/권한 상태/64개 예산/테스트 알람 예약을 눈으로
// 확인한다). 릴리스 빌드에는 포함하지 않는다.
//
// 실행: flutter run -t lib/dev/alarm_harness_main.dart -d <시뮬레이터 UDID>
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler.dart';
import 'package:after30/features/alarm/data/reminder_scheduler_selector.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService().initialize();
  runApp(const AlarmHarnessApp());
}

class AlarmHarnessApp extends StatelessWidget {
  const AlarmHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '알람 엔진 하네스',
      home: AlarmHarnessPage(),
    );
  }
}

class AlarmHarnessPage extends StatefulWidget {
  const AlarmHarnessPage({super.key});

  @override
  State<AlarmHarnessPage> createState() => _AlarmHarnessPageState();
}

class _AlarmHarnessPageState extends State<AlarmHarnessPage> {
  static const String _testAlarmId = 'harness-test-alarm';

  ReminderStrategy? _strategy;
  NotificationAuthorizationStatus? _notifAuth;
  bool? _timeSensitiveAllowed;
  AlarmKitAuthorizationStatus? _alarmKitAuth;
  ReminderBudgetStatus? _budget;
  String? _lastScheduledAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AlarmService.budgetWarnings.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final strategy = await AlarmService.currentReminderStrategy();
    final notifAuth = await DeviceAlarmSettings.notificationAuthorizationStatus();
    final timeSensitive = await DeviceAlarmSettings.isTimeSensitiveAllowed();
    final alarmKitAuth = await DeviceAlarmSettings.alarmKitAuthorizationStatus();
    final budget = await AlarmService.pendingBudget();
    if (!mounted) return;
    setState(() {
      _strategy = strategy;
      _notifAuth = notifAuth;
      _timeSensitiveAllowed = timeSensitive;
      _alarmKitAuth = alarmKitAuth;
      _budget = budget;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _busy = true);
    try {
      await AwesomeNotifications().requestPermissionToSendNotifications();
      final alarmKit = AlarmService.alarmKitScheduler;
      if (alarmKit != null) {
        await alarmKit.requestAuthorization();
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scheduleTestAlarm({required int minutesFromNow}) async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final target = now.add(Duration(minutes: minutesFromNow));
      final day = _koreanWeekday(target.weekday);
      final alarm = MedicineAlarm(
        id: _testAlarmId,
        name: '하네스 테스트 알람',
        times: [TimeOfDay(hour: target.hour, minute: target.minute)],
        days: [day],
      );
      final ok = await AlarmService().scheduleAlarm(alarm);
      setState(() {
        _lastScheduledAt = ok
            ? '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')} ($day, $minutesFromNow분 뒤)'
            : '예약 실패';
      });
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelTestAlarm() async {
    setState(() => _busy = true);
    try {
      await AlarmService().deleteAlarm(_testAlarmId);
      setState(() => _lastScheduledAt = null);
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _koreanWeekday(int isoWeekday) {
    const map = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    return map[isoWeekday] ?? '월';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알람 엔진 하네스 (디버그 전용)')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoTile(label: '선택된 전략', value: _strategy?.name ?? '조회 중...'),
            _InfoTile(label: '알림 권한 상태', value: _notifAuth?.name ?? '조회 중...'),
            _InfoTile(
              label: 'Time Sensitive 허용',
              value: _timeSensitiveAllowed == null ? '조회 중...' : '$_timeSensitiveAllowed',
            ),
            _InfoTile(label: 'AlarmKit 권한 상태', value: _alarmKitAuth?.name ?? '조회 중...'),
            _InfoTile(
              label: '대기 중 로컬 알림 예산',
              value: _budget == null
                  ? '조회 중...'
                  : (_budget!.isLimited
                        ? '${_budget!.used} / ${_budget!.capacity}'
                        : '무제한(Android 또는 AlarmKit)'),
            ),
            _InfoTile(label: '마지막 테스트 알람', value: _lastScheduledAt ?? '없음'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _requestPermissions,
              child: const Text('알림/AlarmKit 권한 요청'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : () => _scheduleTestAlarm(minutesFromNow: 1),
              child: const Text('테스트 알람 1분 뒤 예약'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : () => _scheduleTestAlarm(minutesFromNow: 2),
              child: const Text('테스트 알람 2분 뒤 예약'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _cancelTestAlarm,
              child: const Text('테스트 알람 취소'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : _refresh, child: const Text('상태 새로고침')),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
