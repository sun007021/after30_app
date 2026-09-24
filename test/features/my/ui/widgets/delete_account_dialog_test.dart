import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/features/my/ui/widgets/delete_account_dialog.dart';

import '../../../../support/fake_secure_storage.dart';

/// `DeleteAccountDialog`는 카카오 세션 유무가 아니라 `/users/me`의
/// `provider`로 탈퇴 방식을 분기한다(plan §6 W3a 3항). 이 테스트는 그
/// 분기가 실제로 provider 값을 따라가는지 확인한다("dio 목" 방식).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  Interceptor? mockInterceptor;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    TokenStore.debugOverrideSecureStorage(fakeStorage);
    SharedPreferences.setMockInitialValues({
      'token_store_installed_marker': true,
    });
  });

  tearDown(() {
    if (mockInterceptor != null) {
      ApiClient().dio.interceptors.remove(mockInterceptor);
    }
    TokenStore.debugReset();
  });

  void mockMyProfile(String provider) {
    mockInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/users/me') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'provider': provider},
            ),
          );
          return;
        }
        handler.reject(
          DioException(requestOptions: options, message: '예상하지 못한 경로: ${options.path}'),
        );
      },
    );
    ApiClient().dio.interceptors.add(mockInterceptor!);
  }

  Future<BuildContext> pumpHost(WidgetTester tester, TargetPlatform platform) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Builder(
          builder: (context) {
            captured = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  testWidgets('provider=email + Android: 비밀번호 입력을 위한 Material 다이얼로그를 보여준다', (tester) async {
    mockMyProfile('email');
    final context = await pumpHost(tester, TargetPlatform.android);

    unawaited(DeleteAccountDialog.show(context));
    await tester.pumpAndSettle();

    // 1단계: 탈퇴 확인(DoubleCheckDialog).
    expect(find.text('탈퇴하기'), findsOneWidget);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    // 2단계: provider가 email이므로 비밀번호 입력 다이얼로그로 넘어간다.
    expect(find.text('계정 탈퇴'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
  });

  testWidgets('provider=email + iOS: 비밀번호 입력을 위한 Cupertino 알럿을 보여준다', (tester) async {
    mockMyProfile('email');
    final context = await pumpHost(tester, TargetPlatform.iOS);

    unawaited(DeleteAccountDialog.show(context));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(find.text('계정 탈퇴'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  testWidgets('provider=apple: 아직 지원하지 않는다는 안내만 보여준다(W3b 확장 지점)', (tester) async {
    mockMyProfile('apple');
    final context = await pumpHost(tester, TargetPlatform.android);

    unawaited(DeleteAccountDialog.show(context));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 탈퇴를 지원하지 않습니다'), findsOneWidget);
  });

  testWidgets('provider 조회 실패(네트워크 오류): 오류 다이얼로그를 보여주고 아무 흐름도 타지 않는다', (tester) async {
    mockInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, message: '네트워크 오류'),
        );
      },
    );
    ApiClient().dio.interceptors.add(mockInterceptor!);
    final context = await pumpHost(tester, TargetPlatform.android);

    unawaited(DeleteAccountDialog.show(context));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('계정 정보를 불러오지 못했습니다'), findsOneWidget);
    // 조회 자체가 실패했으므로 카카오/이메일 어느 흐름도 타지 않는다.
    expect(find.text('계정 탈퇴'), findsNothing);
  });

  testWidgets('provider 값만 비어 있음(조회는 성공): 카카오 세션이 없으면 이메일 흐름으로 폴백한다', (
    tester,
  ) async {
    // /users/me는 성공하지만 provider 필드가 없는 경우(예전 백엔드 응답
    // 호환) — 카카오 세션 확인(accessTokenInfo)도 실패하도록 둬서 이메일
    // 흐름 폴백을 확인한다.
    mockInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/users/me') {
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {}),
          );
          return;
        }
        handler.reject(
          DioException(requestOptions: options, message: '예상하지 못한 경로: ${options.path}'),
        );
      },
    );
    ApiClient().dio.interceptors.add(mockInterceptor!);
    final context = await pumpHost(tester, TargetPlatform.android);

    unawaited(DeleteAccountDialog.show(context));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    // 카카오 세션이 없으므로(SDK 미초기화 상태에서 accessTokenInfo 실패)
    // 이메일 탈퇴 흐름(비밀번호 입력)으로 폴백한다.
    expect(find.text('계정 탈퇴'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
