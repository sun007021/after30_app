import 'package:flutter/material.dart';

const double kDaySize = 33.0;
const double kGaugeStroke = 5.0;

/// 완료된 날짜를 표시하는 위젯
class FilledDay extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const FilledDay({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: kDaySize,
        height: kDaySize,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 선택된 날짜를 테두리로 표시하는 위젯
class OutlinedDay extends StatelessWidget {
  final String text;
  final Color color;

  const OutlinedDay({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: kDaySize,
        height: kDaySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 진행률 게이지가 있는 날짜 위젯
class GaugeDay extends StatelessWidget {
  final String text;
  final double percent;
  final Color track;
  final Color progress;

  const GaugeDay({
    super.key,
    required this.text,
    required this.percent,
    required this.track,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0.0, 1.0);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: value),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        builder: (context, animated, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: kDaySize,
                height: kDaySize,
                child: CircularProgressIndicator(
                  value: animated,
                  strokeWidth: kGaugeStroke,
                  backgroundColor: track,
                  color: progress,
                ),
              ),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          );
        },
      ),
    );
  }
}


