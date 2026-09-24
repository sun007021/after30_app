import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/auth/alarm_namespace_migrator.dart';

List<Map<String, dynamic>> _decodeAlarms(String? json_) {
  if (json_ == null) return const [];
  return (json.decode(json_) as List).cast<Map<String, dynamic>>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('카카오 ID로 저장된 알람을 백엔드 ID로 옮긴다', () async {
    SharedPreferences.setMockInitialValues({
      'medicine_alarms_1234567': '[{"id":"a1","name":"타이레놀"}]',
      'notification_ids_1234567_a1': ['100', '101'],
      'notification_ids_1234567_a2': ['200'],
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '1234567',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_42'), '[{"id":"a1","name":"타이레놀"}]');
    expect(prefs.getString('medicine_alarms_1234567'), isNull);
    expect(prefs.getStringList('notification_ids_42_a1'), ['100', '101']);
    expect(prefs.getStringList('notification_ids_42_a2'), ['200']);
    expect(prefs.getStringList('notification_ids_1234567_a1'), isNull);
    expect(prefs.getStringList('notification_ids_1234567_a2'), isNull);
  });

  test('이메일 폴백으로 저장된 알람을 백엔드 ID로 옮긴다', () async {
    SharedPreferences.setMockInitialValues({
      'medicine_alarms_user@example.com': '[{"id":"a1","name":"영양제"}]',
      'notification_ids_user@example.com_a1': ['300'],
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: 'user@example.com',
      newUserId: '99',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_99'), '[{"id":"a1","name":"영양제"}]');
    expect(prefs.getString('medicine_alarms_user@example.com'), isNull);
    expect(prefs.getStringList('notification_ids_99_a1'), ['300']);
  });

  test('이미 새 ID로 저장돼 있으면 아무 것도 하지 않는다(멱등)', () async {
    SharedPreferences.setMockInitialValues({
      'medicine_alarms_42': '[{"id":"a1"}]',
      'notification_ids_42_a1': ['100'],
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '42',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_42'), '[{"id":"a1"}]');
    expect(prefs.getStringList('notification_ids_42_a1'), ['100']);
  });

  test('이전 ID가 없으면(최초 로그인) 아무 것도 하지 않는다', () async {
    SharedPreferences.setMockInitialValues({});

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: null,
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_42'), isNull);
    expect(prefs.getKeys(), isEmpty);
  });

  test('옮길 알람이 없어도(등록한 적 없는 사용자) 에러 없이 끝난다', () async {
    SharedPreferences.setMockInitialValues({'unrelated_key': 'value'});

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '1234567',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('medicine_alarms_42'), isNull);
    expect(prefs.getString('unrelated_key'), 'value');
  });

  test('새 키에 이미 데이터가 있으면 알람 id 기준으로 병합한다(삭제하지 않음)', () async {
    // 리뷰 "ALSO DO": 새 계정에 이미 알람이 있는데 예전 키 데이터를 그냥
    // 지우면, 그 알람에 딸린 OS 예약 알림을 아무도 취소할 수 없는 채로
    // 남는다. 병합해서 두 알람 모두 살아있어야 한다.
    SharedPreferences.setMockInitialValues({
      'medicine_alarms_1234567': '[{"id":"old"}]',
      'medicine_alarms_42': '[{"id":"new"}]',
      'notification_ids_1234567_a1': ['100'],
      'notification_ids_42_a1': ['999'],
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '1234567',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    final merged = _decodeAlarms(prefs.getString('medicine_alarms_42'));
    expect(merged.map((a) => a['id']), containsAll(['old', 'new']));
    expect(merged, hasLength(2));
    expect(prefs.getString('medicine_alarms_1234567'), isNull);
    // notification_ids는 알람 id별 키라서, 같은 키 이름이 이미 새 계정에
    // 있으면(=사실상 같은 알람) 새 값을 유지한다.
    expect(prefs.getStringList('notification_ids_42_a1'), ['999']);
    expect(prefs.getStringList('notification_ids_1234567_a1'), isNull);
  });

  test('알람 id가 겹치면 새 계정 쪽 데이터를 우선한다', () async {
    SharedPreferences.setMockInitialValues({
      'medicine_alarms_1234567': '[{"id":"shared","name":"예전 이름"}]',
      'medicine_alarms_42': '[{"id":"shared","name":"새 이름"}]',
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '1234567',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    final merged = _decodeAlarms(prefs.getString('medicine_alarms_42'));
    expect(merged, hasLength(1));
    expect(merged.single['name'], '새 이름');
  });

  test('inactive_since_<id>_<alarmId>도 함께 옮긴다', () async {
    SharedPreferences.setMockInitialValues({
      'inactive_since_1234567_a1': '2026-01-01',
    });

    await AlarmNamespaceMigrator.migrateIfNeeded(
      oldUserId: '1234567',
      newUserId: '42',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('inactive_since_42_a1'), '2026-01-01');
    expect(prefs.getString('inactive_since_1234567_a1'), isNull);
  });

  group('리뷰 M3: 한 번 마이그레이션된 예전 ID는 다시 쓰지 않는다', () {
    test('같은 예전 ID를 다른 새 ID로 다시 마이그레이션하지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'medicine_alarms_1234567': '[{"id":"a1"}]',
      });

      // 계정 A로 먼저 마이그레이션된다.
      await AlarmNamespaceMigrator.migrateIfNeeded(
        oldUserId: '1234567',
        newUserId: 'accountA',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('medicine_alarms_accountA'), isNotNull);

      // 같은 기기에서 나중에 다른 계정(B)이 로그인하면서, 어떤 이유로든
      // 다시 같은 예전 ID('1234567')를 마이그레이션 후보로 만나더라도
      // (예: 데이터가 남아있었다면) 이미 A로 옮겨졌으니 B로는 옮기지
      // 않는다.
      await prefs.setString('medicine_alarms_1234567', '[{"id":"a1-again"}]');
      await AlarmNamespaceMigrator.migrateIfNeeded(
        oldUserId: '1234567',
        newUserId: 'accountB',
      );

      expect(prefs.getString('medicine_alarms_accountB'), isNull);
      // 이미 마이그레이션된 것으로 표시된 예전 키는 그대로 남아있어도 되고
      // (다시 손대지 않음) 최소한 계정 B로는 넘어가지 않아야 한다.
    });

    test('마이그레이션 후에는 플래그가 저장된다', () async {
      SharedPreferences.setMockInitialValues({
        'medicine_alarms_1234567': '[{"id":"a1"}]',
      });

      await AlarmNamespaceMigrator.migrateIfNeeded(
        oldUserId: '1234567',
        newUserId: '42',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_id_unified_v1_1234567'), isTrue);
    });
  });
}
