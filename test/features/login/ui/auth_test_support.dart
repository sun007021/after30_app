import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/core/network/api_client.dart';
import 'package:after30/core/storage/token_store.dart';

import '../../../support/fake_secure_storage.dart';

/// 지정 플랫폼 테마로 [home]을 띄운다. [routes]는 이동 검증용.
Widget buildAuthApp(
  Widget home,
  TargetPlatform platform, {
  Map<String, WidgetBuilder> routes = const {},
}) {
  return MaterialApp(
    theme: AppTheme.build().copyWith(platform: platform),
    home: home,
    routes: routes,
  );
}

/// 실제 기기와 같은 세이프에어리어(iPhone 16e: 1206x2622, dpr 3, 하단 102)를
/// 흉내 낸다. [keyboard]가 0보다 크면(논리 픽셀) viewInsets로 키보드를 올린다.
void useIphoneViewport(WidgetTester tester, {double keyboard = 0}) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
}

/// 안드로이드 기본 화면(논리 420x900, Responsive 기준값(>400) 적용).
void useAndroidViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1260, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// ApiClient dio에 지연 응답 가짜 백엔드를 붙인다. [calls]에 경로가 쌓인다.
class FakeBackend {
  FakeBackend({required this.delay, this.statusCode = 401, this.data});

  final Duration delay;
  final int statusCode;
  final Map<String, dynamic>? data;
  final List<String> calls = [];

  late final Interceptor _interceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      calls.add(options.path);
      await Future<void>.delayed(delay);
      if (statusCode >= 200 && statusCode < 300) {
        handler.resolve(
          Response(requestOptions: options, statusCode: statusCode, data: data),
        );
      } else {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: statusCode, data: data),
            type: DioExceptionType.badResponse,
          ),
        );
      }
    },
  );

  void install() {
    // 앱 기본 인터셉터보다 먼저 실행되도록 맨 앞에 넣는다.
    ApiClient().dio.interceptors.insert(0, _interceptor);
  }

  void uninstall() => ApiClient().dio.interceptors.remove(_interceptor);
}

void setUpAuthStorage() {
  TokenStore.debugOverrideSecureStorage(FakeSecureStorage());
  SharedPreferences.setMockInitialValues({'token_store_installed_marker': true});
}

void tearDownAuthStorage() => TokenStore.debugReset();
