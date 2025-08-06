import 'package:flutter/material.dart';
import 'package:after30/models/medication.dart';

class MedicationService {
  // 로컬 더미 데이터
  static List<Medication> localDummyData() {
    final now = DateTime.now();
    return [
      Medication(
        id: '1',
        name: '혈압약',
        dosage: '1정',
        time: '아침',
        date: now.subtract(const Duration(days: 2)),
        status: '복용완료',
      ),
      Medication(
        id: '2',
        name: '당뇨약',
        dosage: '1정',
        time: '점심',
        date: now.subtract(const Duration(days: 1)),
        status: '복용완료',
      ),
      Medication(
        id: '3',
        name: '혈압약',
        dosage: '1정',
        time: '저녁',
        date: now,
        status: '복용예정',
      ),
      Medication(
        id: '4',
        name: '당뇨약',
        dosage: '1정',
        time: '아침',
        date: now,
        status: '복용완료',
      ),
    ];
  }

  // 추상화된 fetch 함수 - 현재는 로컬 데이터, 나중에 API로 교체 가능
  static Future<List<Medication>> fetchMedications(
    DateTime start,
    DateTime end,
  ) async {
    // 현재는 로컬 더미 데이터 반환
    await Future.delayed(const Duration(milliseconds: 500)); // 로딩 시뮬레이션

    // 나중에 API 호출로 교체 가능:
    // return await apiService.getMedications(start, end);

    return localDummyData().where((medication) {
      return medication.date.isAfter(start.subtract(const Duration(days: 1))) &&
          medication.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
}

class MedicationProvider extends ChangeNotifier {
  List<Medication> _medications = [];
  bool _isLoading = false;
  String? _error;

  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 특정 날짜의 복용 기록 조회
  List<Medication> getMedicationsForDate(DateTime date) {
    return _medications.where((medication) {
      return medication.date.year == date.year &&
          medication.date.month == date.month &&
          medication.date.day == date.day;
    }).toList();
  }

  // 복용 기록 가져오기
  Future<void> fetchMedications(DateTime start, DateTime end) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final medications = await MedicationService.fetchMedications(start, end);
      _medications = medications;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 복용 상태 업데이트
  void updateMedicationStatus(String id, String status) {
    final index = _medications.indexWhere((med) => med.id == id);
    if (index != -1) {
      final medication = _medications[index];
      _medications[index] = Medication(
        id: medication.id,
        name: medication.name,
        dosage: medication.dosage,
        time: medication.time,
        date: medication.date,
        status: status,
      );
      notifyListeners();
    }
  }
}
