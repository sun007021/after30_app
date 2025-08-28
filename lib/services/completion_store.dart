import 'package:shared_preferences/shared_preferences.dart';

class CompletionStore {
  static const String _completedSetKey = 'dose_completed_set_v1';

  static Future<Set<String>> loadCompletedSet() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_completedSetKey) ?? <String>[];
    return list.toSet();
  }

  static Future<void> markCompleted(String doseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_completedSetKey) ?? <String>[]).toSet();
    set.add(doseKey);
    await prefs.setStringList(_completedSetKey, set.toList());
  }

  static Future<void> unmarkCompleted(String doseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_completedSetKey) ?? <String>[]).toSet();
    set.remove(doseKey);
    await prefs.setStringList(_completedSetKey, set.toList());
  }

  static Future<bool> isCompleted(String doseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_completedSetKey) ?? <String>[];
    return list.contains(doseKey);
  }
}
