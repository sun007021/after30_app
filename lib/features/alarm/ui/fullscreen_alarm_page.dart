import 'package:flutter/material.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class FullscreenAlarmPage extends StatefulWidget {
  final MedicineAlarm alarm;
  final TimeOfDay time;
  final String day;
  final int notificationId;

  const FullscreenAlarmPage({
    super.key,
    required this.alarm,
    required this.time,
    required this.day,
    required this.notificationId,
  });

  @override
  State<FullscreenAlarmPage> createState() => _FullscreenAlarmPageState();
}

class _FullscreenAlarmPageState extends State<FullscreenAlarmPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onCheckOthers(BuildContext context) async {
    // 알림(소리/진동) 정지
    try {
      await AwesomeNotifications().cancel(widget.notificationId);
    } catch (_) {}
    // 홈으로 이동하면서 기존 스택 제거 -> 뒤로가기 시 풀스크린으로 돌아오지 않도록
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  Future<void> _onComplete(BuildContext context) async {
    try {
      final hh = widget.time.hour.toString().padLeft(2, '0');
      final mm = widget.time.minute.toString().padLeft(2, '0');
      await AlarmService.markTakenFromUi(
        medicineName: widget.alarm.name,
        dayKor: widget.day,
        hhmm: '$hh:$mm',
      );
      await AwesomeNotifications().cancel(widget.notificationId);
    } catch (_) {}
    if (context.mounted) {
      // 스택을 정리하고 홈으로 이동하여 스타트업 스피너(무한 로딩) 상태를 피한다
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDate =
        '${now.month}월 ${now.day}일 ${_getDayLongName(now.weekday)}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF2B2B2B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // 상단 시각
                Text(
                  currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 88,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // 날짜/부가 정보
                Column(
                  children: [
                    Text(
                      currentDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '식후 30분',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const Spacer(),
                // 약 이름/안내
                Text(
                  widget.alarm.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '먹을 시간입니다.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // 상단 슬라이드(복용 완료)
                _SlideToActButton(
                  label: '슬라이드하여 복용 완료',
                  backgroundColor: const Color(0xFF3A3A3A),
                  onCompleted: () => _onComplete(context),
                  icon: Icons.check_rounded,
                  iconColor: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                // 하단 슬라이드(약 체크하러 가기)
                _SlideToActButton(
                  label: '슬라이드하여 약 체크하러 가기',
                  backgroundColor: const Color(0xFF505050),
                  onCompleted: () => _onCheckOthers(context),
                  icon: Icons.arrow_forward_rounded,
                  iconColor: Colors.white,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDayLongName(int weekday) {
    const days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return days[weekday - 1];
  }
}

class _SlideToActButton extends StatefulWidget {
  final String label;
  final VoidCallback onCompleted;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  const _SlideToActButton({
    required this.label,
    required this.onCompleted,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<_SlideToActButton> createState() => _SlideToActButtonState();
}

class _SlideToActButtonState extends State<_SlideToActButton> {
  double _dragPx = 0;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final trackHeight = 64.0;
        final knobSize = 56.0;
        final maxDrag = trackWidth - knobSize - 8.0;
        final progress = (_dragPx / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: trackHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(trackHeight / 2),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: 1.0 - progress * 0.8,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4.0 + _dragPx,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (_completed) return;
                    setState(() {
                      _dragPx = (_dragPx + details.delta.dx).clamp(
                        0.0,
                        maxDrag,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    if (_completed) return;
                    if (_dragPx >= maxDrag * 0.85) {
                      _completed = true;
                      widget.onCompleted();
                    } else {
                      setState(() {
                        _dragPx = 0;
                      });
                    }
                  },
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 28),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
