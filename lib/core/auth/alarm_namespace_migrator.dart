import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 사용자 ID가 바뀌었을 때 로컬 알람 저장소(SharedPreferences)의
/// 네임스페이스를 이전 ID에서 새 ID로 옮긴다.
///
/// 배경(plan §1.5, D14 이후 W3a 노트): 예전에는 로그인 경로마다 서로 다른
/// 값을 "현재 사용자 ID"로 저장했다 — 카카오 로그인은 카카오 회원 ID,
/// 이메일 로그인은 JWT에서 뽑은 백엔드 ID(실패 시 이메일 문자열)를
/// 저장했다. `AlarmService`는 이 값으로 `medicine_alarms_<id>`,
/// `notification_ids_<id>_<alarmId>`, `inactive_since_<id>_<alarmId>` 키를
/// 네임스페이스하므로, 같은 사용자가 로그인 방식에 따라 다른 키 아래에
/// 알람이 흩어질 수 있었다.
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

  static String _inactiveSincePrefixFor(String userId) =>
      'inactive_since_${userId}_';

  /// 리뷰 M3: 한 번 다른 ID로 옮겨진(또는 옮길 데이터가 없다고 확인된)
  /// 예전 ID는 다시 마이그레이션 소스로 쓰지 않는다. 이 플래그가 없으면,
  /// 예를 들어 부모 폰에서 자녀 계정이 로그인해 있다가 부모가 다시
  /// 로그인했을 때 서로 다른 두 백엔드 계정 사이에서 데이터가 잘못
  /// 오가는 경로가 생길 수 있다.
  static String _claimedFlagKeyFor(String legacyUserId) =>
      'user_id_unified_v1_$legacyUserId';

  /// [oldUserId]에 저장된 알람/알림 ID/비활성 기록을 [newUserId] 키로
  /// 옮긴다(둘 다에 데이터가 있으면 알람 ID 기준으로 병합한다).
  ///
  /// - [oldUserId]가 null이거나 [newUserId]와 같으면(최초 로그인이거나 이미
  ///   같은 ID로 저장돼 있으면) 아무 것도 하지 않는다(멱등).
  /// - [oldUserId]가 이미 다른 ID로 마이그레이션된 적이 있으면(M3) 아무
  ///   것도 하지 않는다.
  /// - 옮길 데이터가 없으면(알람을 등록한 적 없는 사용자) 플래그만 남기고
  ///   조용히 끝난다.
  static Future<void> migrateIfNeeded({
    required String? oldUserId,
    required String newUserId,
  }) async {
    if (oldUserId == null || oldUserId == newUserId) return;

    final prefs = await SharedPreferences.getInstance();

    final claimedFlagKey = _claimedFlagKeyFor(oldUserId);
    if (prefs.getBool(claimedFlagKey) ?? false) return;

    // 1) medicine_alarms_<old> -> medicine_alarms_<new> (알람 id 기준 병합)
    final oldAlarmsKey = _alarmsKeyFor(oldUserId);
    final newAlarmsKey = _alarmsKeyFor(newUserId);
    final oldAlarmsJson = prefs.getString(oldAlarmsKey);
    if (oldAlarmsJson != null) {
      final newAlarmsJson = prefs.getString(newAlarmsKey);
      final merged = _mergeAlarmListsJson(newAlarmsJson, oldAlarmsJson);
      if (merged == null) {
        // 어느 쪽 JSON이든 파싱에 실패하면 아무것도 옮기거나 지우지 않는다.
        // 이전 키를 지우면 정상이던 알람 목록이 사라진다. 완료 플래그도
        // 남기지 않아 다음 로그인/복원 때 다시 시도하게 한다.
        return;
      }
      await prefs.setString(newAlarmsKey, merged);
      await prefs.remove(oldAlarmsKey);
    }

    // 2) notification_ids_<old>_<alarmId> -> notification_ids_<new>_<alarmId>
    await _moveKeyedByAlarmIdStringList(
      prefs: prefs,
      oldPrefix: _notificationIdsPrefixFor(oldUserId),
      newPrefix: _notificationIdsPrefixFor(newUserId),
    );

    // 3) inactive_since_<old>_<alarmId> -> inactive_since_<new>_<alarmId>
    await _moveKeyedByAlarmIdString(
      prefs: prefs,
      oldPrefix: _inactiveSincePrefixFor(oldUserId),
      newPrefix: _inactiveSincePrefixFor(newUserId),
    );

    await prefs.setBool(claimedFlagKey, true);
  }

  /// 알람 목록 두 개(JSON 배열 문자열)를 알람 `id` 기준으로 병합한다.
  /// 같은 id가 양쪽에 있으면(드문 경우) 새 계정 쪽 값을 우선한다. 어느
  /// 쪽이든 파싱에 실패하면 null을 반환해 호출부가 양쪽 키를 모두 그대로
  /// 두게 한다.
  static String? _mergeAlarmListsJson(String? newJson, String oldJson) {
    try {
      final byId = <String, Map<String, dynamic>>{};

      final oldList = (json.decode(oldJson) as List).cast<Map<String, dynamic>>();
      for (final alarm in oldList) {
        final id = alarm['id']?.toString();
        if (id != null) byId[id] = alarm;
      }

      if (newJson != null) {
        final newList = (json.decode(newJson) as List).cast<Map<String, dynamic>>();
        for (final alarm in newList) {
          // 새 계정에 이미 있는 항목이 우선한다(같은 id가 있다면 최신 데이터).
          final id = alarm['id']?.toString();
          if (id != null) byId[id] = alarm;
        }
      }

      return json.encode(byId.values.toList());
    } catch (_) {
      return null;
    }
  }

  /// `<prefix><alarmId>` 형태의 문자열 리스트 키들을 옮긴다. 새 쪽에 이미
  /// 값이 있으면(같은 alarmId) 두 목록을 합친다(새 쪽 ID가 앞, 중복 제거).
  /// 이전 ID를 버리면 그 ID로 이미 예약된 OS 알림을 아무도 취소할 수 없게
  /// 된다. `scheduleAlarm`은 목록의 ID를 모두 취소한 뒤 필요한 개수만 다시
  /// 쓰므로 다음 재예약 때 저절로 정리된다.
  static Future<void> _moveKeyedByAlarmIdStringList({
    required SharedPreferences prefs,
    required String oldPrefix,
    required String newPrefix,
  }) async {
    final oldKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(oldPrefix))
        .toList(growable: false);

    for (final oldKey in oldKeys) {
      final alarmId = oldKey.substring(oldPrefix.length);
      final newKey = '$newPrefix$alarmId';
      final oldIds = prefs.getStringList(oldKey) ?? const <String>[];
      final newIds = prefs.getStringList(newKey);
      final mergedIds = <String>[
        ...?newIds,
        ...oldIds.where((id) => !(newIds?.contains(id) ?? false)),
      ];
      await prefs.setStringList(newKey, mergedIds);
      await prefs.remove(oldKey);
    }
  }

  /// [_moveKeyedByAlarmIdStringList]와 같지만 값이 단일 문자열인 키(예:
  /// `inactive_since_<id>_<alarmId>`)용이다.
  static Future<void> _moveKeyedByAlarmIdString({
    required SharedPreferences prefs,
    required String oldPrefix,
    required String newPrefix,
  }) async {
    final oldKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(oldPrefix))
        .toList(growable: false);

    for (final oldKey in oldKeys) {
      final alarmId = oldKey.substring(oldPrefix.length);
      final newKey = '$newPrefix$alarmId';
      if (prefs.getString(newKey) == null) {
        final value = prefs.getString(oldKey);
        if (value != null) {
          await prefs.setString(newKey, value);
        }
      }
      await prefs.remove(oldKey);
    }
  }
}
