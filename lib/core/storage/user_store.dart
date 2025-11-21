import 'package:shared_preferences/shared_preferences.dart';

class UserStore {
  static const _kCurrentUserIdKey = 'current_user_id';

  static Future<void> setCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserIdKey, userId);
  }

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrentUserIdKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserIdKey);
  }
}
