import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/auth/alarm_namespace_migrator.dart';

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

  test('새 키에 이미 데이터가 있으면 덮어쓰지 않고 이전 키만 정리한다', () async {
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
    expect(prefs.getString('medicine_alarms_42'), '[{"id":"new"}]');
    expect(prefs.getString('medicine_alarms_1234567'), isNull);
    expect(prefs.getStringList('notification_ids_42_a1'), ['999']);
    expect(prefs.getStringList('notification_ids_1234567_a1'), isNull);
  });
}
