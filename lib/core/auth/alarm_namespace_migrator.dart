import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 사용자 ID가 바뀌었을 때 로컬 알람 저장소(SharedPreferences)의
/// 네임스페이스를 이전 ID에서 새 ID로 옮긴다.
///
/// 배경(plan §1.5, D14 이후 W3a 노트): 예전에는 로그인 경로마다 서로 다른
/// 값을 "현재 사용자 ID"로 저장했다 — 카카오 로그인은 카카오 회원 ID,
/// 이메일 로그인은 JWT에서 뽑은 백엔드 ID(실패 시 이메일 문자열)를
/// 저장했다. `AlarmService`는 이 값으로 `medicine_alarms_<id>`,
/// `notification_ids_<id>_<alarmId>` 키를 네임스페이스하므로, 같은
/// 사용자가 로그인 방식에 따라 다른 키 아래에 알람이 흩어질 수 있었다.
///
/// 이제 모든 로그인 경로가 백엔드 사용자 ID로 통일되므로([SessionBootstrapper]
/// 참고), 기존에 다른 ID로 저장돼 있던 사용자가 새 ID로 처음 로그인할 때
/// 저장된 알람 데이터를 새 키로 옮겨야 데이터가 사라지지 않는다.
///
/// 실제 OS에 예약된 알림(awesome_notifications) 자체는 건드리지 않는다 —
/// 여기서는 "어떤 알림 ID들이 어느 알람에 속하는지"를 기록한 SharedPreferences
/// 항목의 키 이름만 옮긴다. 알림 ID 자체는 그대로 유지되므로, 이후
/// `AlarmService.rescheduleAllActiveFromStorage()`가 기존 ID를 재사용해
/// 중복 예약이 생기지 않는다.
class AlarmNamespaceMigrator {
  AlarmNamespaceMigrator._();

  static String _alarmsKeyFor(String userId) => 'medicine_alarms_$userId';

  static String _notificationIdsPrefixFor(String userId) =>
      'notification_ids_${userId}_';

  /// [oldUserId]에 저장된 알람/알림 ID 데이터를 [newUserId] 키로 옮긴다.
  ///
  /// - [oldUserId]가 null이거나 [newUserId]와 같으면(최초 로그인이거나 이미
  ///   같은 ID로 저장돼 있으면) 아무 것도 하지 않는다(멱등).
  /// - 옮길 데이터가 없으면(알람을 등록한 적 없는 사용자) 조용히 끝난다.
  static Future<void> migrateIfNeeded({
    required String? oldUserId,
    required String newUserId,
  }) async {
    if (oldUserId == null || oldUserId == newUserId) return;

    final prefs = await SharedPreferences.getInstance();

    // 1) medicine_alarms_<old> -> medicine_alarms_<new>
    final oldAlarmsKey = _alarmsKeyFor(oldUserId);
    final newAlarmsKey = _alarmsKeyFor(newUserId);
    final oldAlarmsJson = prefs.getString(oldAlarmsKey);
    if (oldAlarmsJson != null) {
      // 새 키에 이미 데이터가 있으면(드문 경우, 예: 동시 로그인) 덮어쓰지
      // 않고 이전 키만 정리한다.
      if (prefs.getString(newAlarmsKey) == null) {
        await prefs.setString(newAlarmsKey, oldAlarmsJson);
      }
      await prefs.remove(oldAlarmsKey);
    }

    // 2) notification_ids_<old>_<alarmId> -> notification_ids_<new>_<alarmId>
    final oldPrefix = _notificationIdsPrefixFor(oldUserId);
    final newPrefix = _notificationIdsPrefixFor(newUserId);
    final oldNotificationKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(oldPrefix))
        .toList(growable: false);

    for (final oldKey in oldNotificationKeys) {
      final alarmId = oldKey.substring(oldPrefix.length);
      final newKey = '$newPrefix$alarmId';
      final ids = prefs.getStringList(oldKey);
      if (ids != null && prefs.getStringList(newKey) == null) {
        await prefs.setStringList(newKey, ids);
      }
      await prefs.remove(oldKey);
    }
  }
}
