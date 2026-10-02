import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

/// "복용 완료" 서버 기록 함수 형태(테스트에서 가짜를 주입한다).
typedef MarkTakenFn =
    Future<bool> Function({
      required String medicineName,
      required String dayKor,
      required String hhmm,
    });

class FullscreenAlarmPage extends StatefulWidget {
  final MedicineAlarm alarm;
  final TimeOfDay time;
  final String day;
  final int notificationId;

  /// 지정하지 않으면 실제 [AlarmService.markTakenFromUi]를 쓴다.
  final MarkTakenFn? markTaken;

  const FullscreenAlarmPage({
    super.key,
    required this.alarm,
    required this.time,
    required this.day,
    required this.notificationId,
    this.markTaken,
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
    // 알림(소리/진동) 정지. `cancel()`은 표시된 알림뿐 아니라 반복 예약까지
    // 취소해 버려서(리뷰 B1), 요일이 합쳐진 iOS 매일 알람은 한 번만 눌러도
    // 7일치가 전부 사라졌다. 지금 울리고 있는 알림만 닫는 `dismiss()`로
    // 바꾼다.
    try {
      await AwesomeNotifications().dismiss(widget.notificationId);
    } catch (_) {}
    // 홈으로 이동하면서 기존 스택 제거 -> 뒤로가기 시 풀스크린으로 돌아오지 않도록
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  Future<bool> _onComplete(BuildContext context) async {
    bool success = false;
    try {
      final hh = widget.time.hour.toString().padLeft(2, '0');
      final mm = widget.time.minute.toString().padLeft(2, '0');
      success = await (widget.markTaken ?? AlarmService.markTakenFromUi)(
        medicineName: widget.alarm.name,
        dayKor: widget.day,
        hhmm: '$hh:$mm',
      );
    } catch (_) {
      success = false;
    }
    if (!success) {
      // 서버 기록 실패(스케줄 매칭 실패, 네트워크 오류 등): 화면을 닫지 않고
      // 사용자가 다시 시도할 수 있도록 알린다.
      if (context.mounted) {
        AppToast.show(
          context,
          '복용 완료 처리에 실패했습니다. 다시 시도해주세요.',
          type: AppToastType.error,
        );
      }
      return false;
    }
    try {
      // 리뷰 B1: `cancel()`은 반복 예약까지 지워버리므로 `dismiss()`로
      // 지금 표시된 알림만 닫는다.
      await AwesomeNotifications().dismiss(widget.notificationId);
    } catch (_) {}
    if (context.mounted) {
      // 스택을 정리하고 홈으로 이동하여 스타트업 스피너(무한 로딩) 상태를 피한다
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDate =
        '${now.month}월 ${now.day}일 ${_getDayLongName(now.weekday)}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final cupertino = isCupertino(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // 상단 시각. Dynamic Type/작은 화면에서도 넘치지 않도록 줄여서 맞춘다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 88,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          // 날짜/부가 정보
          Column(
            children: [
              Text(
                currentDate,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '식후 30분',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
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
              color: Colors.white.withValues(alpha: 0.9),
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
            onCompleted: () async {
              await _onCheckOthers(context);
              return true;
            },
            icon: Icons.arrow_forward_rounded,
            iconColor: Colors.white,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    // 알람 화면은 뒤로 가기로 닫을 수 없다(슬라이드로만 종료).
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF2B2B2B),
        body: SafeArea(
          // iOS: 접근성 글꼴 크기를 키워도 레이아웃이 깨지지 않도록 배율 상한을 둔다.
          child: cupertino ? AppTypography.clampTextScale(child: content) : content,
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
  // 성공 여부를 반환한다. 실패 시 슬라이드 상태를 되돌려 재시도할 수 있게 한다.
  final Future<bool> Function() onCompleted;
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

        final cupertino = isCupertino(context);
        final track = Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: 1.0 - progress * 0.8,
                  child: cupertino
                      // 큰 글꼴에서도 노브와 겹치지 않도록 좌우 여백을 두고
                      // 줄여서 맞춘다.
                      ? Padding(
                          padding: const EdgeInsets.only(left: 68, right: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(widget.label, style: _labelStyle),
                          ),
                        )
                      : Text(widget.label, style: _labelStyle),
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
                  onPanEnd: (_) async {
                    if (_completed) return;
                    if (_dragPx >= maxDrag * 0.85) {
                      setState(() {
                        _completed = true;
                      });
                      final success = await widget.onCompleted();
                      if (!context.mounted) return;
                      if (success) {
                        AppHaptics.success(context);
                      } else {
                        // 실패 시 잠금을 풀고 위치를 되돌려 재시도할 수 있게 한다.
                        setState(() {
                          _completed = false;
                          _dragPx = 0;
                        });
                      }
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
                          color: Colors.black.withValues(alpha: 0.25),
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
          );

        // iOS: 내비게이션 레이어 성격의 캡슐 글래스 트랙(§4.1). Android는 기존
        // 불투명 트랙을 그대로 쓴다.
        if (cupertino) {
          return SizedBox(
            height: trackHeight,
            child: GlassSurface(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(trackHeight / 2),
              ),
              tintOpacity: 0.16,
              child: track,
            ),
          );
        }
        return Container(
          height: trackHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(trackHeight / 2),
          ),
          child: track,
        );
      },
    );
  }

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
