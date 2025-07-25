import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class UserProvider extends ChangeNotifier {
  int? _userId;
  String? _userName;

  int? get userId => _userId;
  String? get userName => _userName;

  bool get isUserLoaded => _userId != null && _userName != null;

  Future<void> loadUser() async {
    final user = await SecureStorageService.getUser();
    _userId = int.tryParse(user['user_id'] ?? '');
    _userName = user['user_name'];
    notifyListeners();
  }

  Future<void> saveUser({required int userId, required String userName}) async {
    _userId = userId;
    _userName = userName;
    await SecureStorageService.saveUser(userId: userId, userName: userName);
    notifyListeners();
  }

  Future<void> clearUser() async {
    _userId = null;
    _userName = null;
    await SecureStorageService.clearUser();
    notifyListeners();
  }
}
