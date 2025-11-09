class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time; // HH:mm
  final DateTime date; // scheduled date (local)
  final String status; // pending|taken|postponed|cancelled|missed
  final bool nfcEnabled;
  final int? scheduleId;
  final int? historyId;
  final DateTime? takenAt;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.date,
    required this.status,
    this.nfcEnabled = false,
    this.scheduleId,
    this.historyId,
    this.takenAt,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? time,
    DateTime? date,
    String? status,
    bool? nfcEnabled,
    int? scheduleId,
    int? historyId,
    DateTime? takenAt,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      date: date ?? this.date,
      status: status ?? this.status,
      nfcEnabled: nfcEnabled ?? this.nfcEnabled,
      scheduleId: scheduleId ?? this.scheduleId,
      historyId: historyId ?? this.historyId,
      takenAt: takenAt ?? this.takenAt,
    );
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['medication_name'] ?? '').toString(),
      dosage: (json['dosage'] ?? json['dosage_value'] ?? '').toString(),
      time: (json['time'] ?? json['scheduled_time'] ?? '00:00').toString(),
      date:
          DateTime.tryParse(
            (json['date'] ?? json['scheduled_date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      status: (json['status'] ?? 'pending').toString(),
      nfcEnabled: (json['nfcEnabled'] as bool?) ?? false,
      scheduleId: (json['schedule_id'] as num?)?.toInt(),
      historyId: (json['history_id'] as num?)?.toInt(),
      takenAt: json['taken_at'] != null
          ? DateTime.tryParse(json['taken_at'].toString())
          : null,
    );
  }
}
