class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final DateTime date;
  final String status;
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

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'],
      time: json['time'],
      date: DateTime.parse(json['date']),
      status: json['status'],
      nfcEnabled: json['nfcEnabled'] ?? false,
      scheduleId: json['scheduleId'],
      historyId: json['historyId'],
      takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'date': date.toIso8601String(),
      'status': status,
      'nfcEnabled': nfcEnabled,
      'scheduleId': scheduleId,
      'historyId': historyId,
      'takenAt': takenAt?.toIso8601String(),
    };
  }

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
}
