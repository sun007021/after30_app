import 'package:flutter/material.dart';
import 'package:after30/models/medicine_alarm.dart';

class FullscreenAlarm extends StatefulWidget {
  final MedicineAlarm alarm;
  final TimeOfDay time;
  final String day;

  const FullscreenAlarm({
    super.key,
    required this.alarm,
    required this.time,
    required this.day,
  });

  @override
  State<FullscreenAlarm> createState() => _FullscreenAlarmState();
}

class _FullscreenAlarmState extends State<FullscreenAlarm>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  bool _isSliding = false;
  double _slideOffset = 0.0;

  @override
  void initState() {
    super.initState();

    // 슬라이드 애니메이션 컨트롤러
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 펄스 애니메이션 컨트롤러
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 펄스 애니메이션 시작
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _snoozeAlarm() {
    // 10분 미루기
    Navigator.of(context).pop('snooze');
  }

  void _checkOtherMedicines() {
    // 다른 약 체크
    Navigator.of(context).pop('check_others');
  }

  void _completeDosage() {
    // 복용 완료
    Navigator.of(context).pop('completed');
  }

  void _onSlideUpdate(DragUpdateDetails details) {
    setState(() {
      _slideOffset += details.primaryDelta ?? 0.0;
      // 슬라이드 범위 제한
      if (_slideOffset < 0) _slideOffset = 0;
      if (_slideOffset > 200) _slideOffset = 200;
    });
  }

  void _onSlideEnd(DragEndDetails details) {
    if (_slideOffset > 100) {
      // 오른쪽으로 충분히 슬라이드하면 복용 완료
      _slideController.forward().then((_) {
        _completeDosage();
      });
    } else {
      // 원래 위치로 돌아가기
      setState(() {
        _slideOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentDate = '${now.month}월 ${now.day}일 ${_getDayName(now.weekday)}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 날짜와 시간
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentDate,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Text(
                            currentTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 중앙 알림 상자
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.alarm.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '드실 시간 입니다!',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 하단 액션 카드
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      '복용체크 해주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _snoozeAlarm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('10분 미루기'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _checkOtherMedicines,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('이외 약 체크'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 슬라이드 액션
                    GestureDetector(
                      onPanUpdate: _onSlideUpdate,
                      onPanEnd: _onSlideEnd,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Stack(
                          children: [
                            // 슬라이드 진행률 표시
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _slideOffset + 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),

                            // 슬라이드 배경 텍스트
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  '밀어서 체크하기',
                                  style: TextStyle(
                                    color: _slideOffset > 50
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            // 슬라이드 핸들
                            Positioned(
                              left: _slideOffset,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}
