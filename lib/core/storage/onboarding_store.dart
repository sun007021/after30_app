import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  static const _kCompletedKey = 'onboarding_completed';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCompletedKey) ?? false;
  }

  static Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompletedKey, true);
  }
}
