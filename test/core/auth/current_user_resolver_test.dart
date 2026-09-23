import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/auth/current_user_resolver.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/family/models/group_member.dart';

import '../storage/fake_secure_storage.dart';

/// [parseUserIdFromJwt]는 페이로드(두 번째 세그먼트)만 읽으므로, 헤더/서명은
/// 아무 문자열이나 넣어도 된다.
String _fakeJwt(Map<String, dynamic> payload) {
  final encodedPayload = base64Url
      .encode(utf8.encode(json.encode(payload)))
      .replaceAll('=', '');
  return 'header.$encodedPayload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;

  // resolveUserId의 가족 구성원 폴백 경로는 MyProfileService().getMyProfile()
  // (실제 백엔드 `/users/me`)을 호출한다. 테스트에서는 실제 네트워크를 타면
  // 안 되므로, dio 요청을 즉시 실패시키는 인터셉터로 막는다("dio 목" 방식).
  late Interceptor blockNetworkInterceptor;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    TokenStore.debugOverrideSecureStorage(fakeStorage);
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
    });
    blockNetworkInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            message: '테스트 환경에서는 네트워크를 사용하지 않는다',
          ),
        );
      },
    );
    ApiClient().dio.interceptors.add(blockNetworkInterceptor);
  });

  tearDown(() {
    TokenStore.debugReset();
    ApiClient().dio.interceptors.remove(blockNetworkInterceptor);
  });

  group('parseUserIdFromJwt', () {
    test('sub 클레임을 정수로 파싱한다', () {
      final token = _fakeJwt({'sub': 42});
      expect(CurrentUserResolver.parseUserIdFromJwt(token), 42);
    });

    test('sub이 문자열이어도 파싱한다', () {
      final token = _fakeJwt({'sub': '42'});
      expect(CurrentUserResolver.parseUserIdFromJwt(token), 42);
    });

    test('sub이 없으면 user_id, id 순으로 찾는다', () {
      expect(CurrentUserResolver.parseUserIdFromJwt(_fakeJwt({'user_id': 7})), 7);
      expect(CurrentUserResolver.parseUserIdFromJwt(_fakeJwt({'id': 9})), 9);
    });

    test('세그먼트가 2개 미만이거나 파싱할 수 없으면 null을 반환한다', () {
      expect(CurrentUserResolver.parseUserIdFromJwt('not-a-jwt'), isNull);
      expect(CurrentUserResolver.parseUserIdFromJwt(_fakeJwt({'other': 1})), isNull);
    });
  });

  group('resolveUserId', () {
    test('JWT를 저장된 값보다 우선한다(카카오 ID 등 예전 값이 남아있어도 백엔드 ID를 쓴다)', () async {
      // 예전에 카카오 로그인으로 저장된 값이 남아있는 상황을 흉내낸다.
      await UserStore.setCurrentUserId('1234567');
      await TokenStore.saveTokens(
        accessToken: _fakeJwt({'sub': 42}),
        refreshToken: 'r',
        accessExpiresIn: 3600,
        refreshExpiresIn: 86400,
      );

      final resolved = await CurrentUserResolver.resolveUserId();

      expect(resolved, 42);
      // 부수효과로 UserStore도 새 값으로 갱신돼야 한다.
      expect(await UserStore.getCurrentUserId(), '42');
    });

    test('토큰이 없으면 저장된 값으로 폴백한다', () async {
      await UserStore.setCurrentUserId('55');

      final resolved = await CurrentUserResolver.resolveUserId();

      expect(resolved, 55);
    });

    test('토큰도 저장된 값도 없고 구성원이 1명뿐이면 그 사람으로 폴백한다', () async {
      // resolveUserId의 이 분기는 이름이 일치하는 구성원을 먼저 찾고, 못
      // 찾았지만 구성원이 1명뿐이면 그 사람으로 폴백한다. 두 시도 모두
      // `/users/me` 응답(내 이름)이 있어야 도달하므로, 이름이 일치하지
      // 않는 프로필을 목으로 응답해 "1명뿐이라 폴백" 분기를 검증한다.
      ApiClient().dio.interceptors.remove(blockNetworkInterceptor);
      final profileInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {'name': '이름불일치'}),
          );
        },
      );
      ApiClient().dio.interceptors.add(profileInterceptor);
      addTearDown(() => ApiClient().dio.interceptors.remove(profileInterceptor));

      final onlyMember = GroupMember(
        id: 1,
        groupId: 1,
        userId: 20,
        userName: '나',
        role: 'MEMBER',
        joinedAt: DateTime(2026, 1, 1),
        isActive: true,
      );

      final resolved = await CurrentUserResolver.resolveUserId(
        members: [onlyMember],
      );

      expect(resolved, 20);
    });

    test('아무 단서도 없으면 null을 반환한다', () async {
      final resolved = await CurrentUserResolver.resolveUserId();
      expect(resolved, isNull);
    });
  });
}
