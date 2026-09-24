import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';


/// 항상 예외를 던지는 가짜 보안 저장소.
class _ThrowingSecureStorage implements SecureStorageAdapter {
  @override
  Future<String?> read(String key) async => throw Exception('keystore broken');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('keystore broken');

  @override
  Future<void> delete(String key) async => throw Exception('keystore broken');
}

/// 리뷰 M1: `ApiClient`의 요청 인터셉터가 `TokenStore` 접근 실패 시 요청을
/// 영원히 멈추게 하지 않는지 검증한다(D8 이전에는 SharedPreferences가
/// 예외를 던진 적이 없어 문제가 없었지만, Keychain/Keystore 이전 이후로는
/// 실제로 발생할 수 있다 — 기기 잠금 중 백그라운드 알림 액션, Android
/// Auto Backup으로 복원된 파일에 맞는 Keystore 키가 없는 경우 등).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
    });
  });

  tearDown(() {
    TokenStore.debugReset();
  });

  test('보안 저장소가 예외를 던져도 요청이 멈추지 않고 끝난다(행 없음)', () async {
    TokenStore.debugOverrideSecureStorage(_ThrowingSecureStorage());

    // 실제 네트워크 대신, 인터셉터 체인이 handler.next까지 도달했는지만
    // 확인하는 종단 인터셉터를 하나 둔다.
    final terminal = InterceptorsWrapper(
      onRequest: (options, handler) =>
          handler.resolve(Response(requestOptions: options, data: 'ok')),
    );
    ApiClient().dio.interceptors.add(terminal);
    addTearDown(() => ApiClient().dio.interceptors.remove(terminal));

    // 예전 구현은 onRequest 콜백 안에서 예외가 나면 next도 reject도 호출되지
    // 않아 이 요청이 영원히 완료되지 않았다. 여기서는 짧은 타임아웃으로
        // "행"과 "정상 종료(성공 또는 실패)"를 구분한다.
    Object? outcome;
    try {
      await ApiClient().dio.get('/users/me').timeout(const Duration(seconds: 2));
      outcome = 'completed';
    } on TimeoutException {
      outcome = 'HANG';
    } catch (e) {
      outcome = 'error';
    }

    expect(outcome, isNot('HANG'));
  });

  test('보안 저장소가 예외를 던지면 Authorization 헤더 없이도 요청이 끝난다', () async {
    TokenStore.debugOverrideSecureStorage(_ThrowingSecureStorage());

    RequestOptions? capturedOptions;
    final terminal = InterceptorsWrapper(
      onRequest: (options, handler) {
        capturedOptions = options;
        handler.resolve(Response(requestOptions: options, data: 'ok'));
      },
    );
    ApiClient().dio.interceptors.add(terminal);
    addTearDown(() => ApiClient().dio.interceptors.remove(terminal));

    await ApiClient().dio.get('/users/me').timeout(const Duration(seconds: 2));

    // TokenStore.getAccessToken()이 null을 반환하므로(M1②) Authorization
    // 헤더가 아예 붙지 않은 채로 요청이 정상 진행돼야 한다.
    expect(capturedOptions?.headers['Authorization'], isNull);
  });
}
