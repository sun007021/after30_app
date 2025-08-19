import 'package:flutter/material.dart';

class MedicineAlarm {
  final String id;
  final String name;
  final List<TimeOfDay> times;
  final List<String> days; // ['월', '화', ...]
  final bool everyDay;
  final bool isActive;
  final bool nfcEnabled;
  final bool familyNotify;
  final DateTime createdAt;

  MedicineAlarm({
    String? id,
    required this.name,
    required this.times,
    required this.days,
    this.everyDay = false,
    this.isActive = true,
    this.nfcEnabled = false,
    this.familyNotify = true,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  MedicineAlarm copyWith({
    String? id,
    String? name,
    List<TimeOfDay>? times,
    List<String>? days,
    bool? everyDay,
    bool? isActive,
    bool? nfcEnabled,
    bool? familyNotify,
    DateTime? createdAt,
  }) {
    return MedicineAlarm(
      id: id ?? this.id,
      name: name ?? this.name,
      times: times ?? this.times,
      days: days ?? this.days,
      everyDay: everyDay ?? this.everyDay,
      isActive: isActive ?? this.isActive,
      nfcEnabled: nfcEnabled ?? this.nfcEnabled,
      familyNotify: familyNotify ?? this.familyNotify,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'times': times.map((t) => '${t.hour}:${t.minute}').toList(),
      'days': days,
      'everyDay': everyDay,
      'isActive': isActive,
      'nfcEnabled': nfcEnabled,
      'familyNotify': familyNotify,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MedicineAlarm.fromJson(Map<String, dynamic> json) {
    return MedicineAlarm(
      id: json['id'],
      name: json['name'],
      times: (json['times'] as List).map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
      days: List<String>.from(json['days']),
      everyDay: json['everyDay'] ?? false,
      isActive: json['isActive'] ?? true,
      nfcEnabled: json['nfcEnabled'] ?? false,
      familyNotify: json['familyNotify'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
