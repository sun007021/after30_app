import 'package:flutter/material.dart';

class MedicineAlarm {
  final String name;
  final List<TimeOfDay> times;
  final List<String> days; // ['월', '화', ...]
  final bool everyDay;
  // 추가 필드: nfc, 가족 알림 등 필요시

  MedicineAlarm({
    required this.name,
    required this.times,
    required this.days,
    this.everyDay = false,
  });
}
