import 'package:shared_preferences/shared_preferences.dart';

class MySettingsStore {
  static const _kAllowFamilyNotifications = 'allow_family_notifications';
  static const _kAllowPushNotifications = 'allow_push_notifications';
  static const _kAllowDeviceNotifications = 'allow_device_notifications';

  static Future<void> setAllowFamilyNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowFamilyNotifications, value);
  }

  static Future<bool> getAllowFamilyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAllowFamilyNotifications) ?? true;
  }

  static Future<void> setAllowPushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowPushNotifications, value);
  }

  static Future<bool> getAllowPushNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAllowPushNotifications) ?? true;
  }

  static Future<void> setAllowDeviceNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowDeviceNotifications, value);
  }

  static Future<bool> getAllowDeviceNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAllowDeviceNotifications) ?? true;
  }
}

