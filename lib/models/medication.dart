class Medication {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final DateTime date;
  final String status;
  final bool nfcEnabled;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.date,
    required this.status,
    this.nfcEnabled = false,
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
    };
  }
}
