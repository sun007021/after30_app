import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/features/my/device_alarm_gateway.dart';
import 'package:after30/features/my/my_info_edit_page.dart';
import 'package:after30/features/my/my_info_page.dart';
import 'package:after30/features/my/my_page.dart';

/// 지연/실패/호출 횟수를 조절할 수 있는 가짜 프로필 서비스.
class FakeMyProfileService extends MyProfileService {
  FakeMyProfileService({
    this.profile,
    this.getDelay = Duration.zero,
    this.updateDelay = Duration.zero,
  });

  MyProfile? profile;
  final Duration getDelay;
  final Duration updateDelay;

  int getCalls = 0;
  int updateCalls = 0;
  int phoneUpdateCalls = 0;
  bool failGet = false;

  /// 앞에서부터 하나씩 소모하며 던진다(null이면 성공).
  final List<Object?> updateErrors = [];

  @override
  Future<MyProfile> getMyProfile() async {
    getCalls++;
    if (failGet) throw Exception('network');
    final snapshot = profile ?? MyProfile(name: '홍길동');
    if (getDelay > Duration.zero) await Future<void>.delayed(getDelay);
    return snapshot;
  }

  @override
  Future<MyProfile> updateMyProfile({
    required String name,
    required String gender,
    required String phoneNumber,
  }) async {
    updateCalls++;
    if (updateDelay > Duration.zero) await Future<void>.delayed(updateDelay);
    if (updateErrors.isNotEmpty) {
      final error = updateErrors.removeAt(0);
      if (error != null) throw error;
    }
    profile = MyProfile(
      name: name,
      gender: gender,
      phoneNumber: phoneNumber,
      provider: profile?.provider,
      email: profile?.email,
    );
    return profile!;
  }

  @override
  Future<void> updatePhoneNumber(String phoneNumber) async {
    phoneUpdateCalls++;
    profile = MyProfile(
      name: profile?.name,
      email: profile?.email,
      provider: profile?.provider,
      gender: profile?.gender,
      phoneNumber: phoneNumber,
    );
  }
}

class FakeMyUserService extends UserService {
  @override
  Future<bool> isPhoneDuplicate(String phoneNumber) async => false;
}

class FakeDeviceAlarmGateway extends MyDeviceAlarmGateway {
  FakeDeviceAlarmGateway({MyDeviceAlarmStatus? status})
    : status = status ?? authorizedStatus;

  MyDeviceAlarmStatus status;
  int loadCalls = 0;
  int openSettingsCalls = 0;

  static const authorizedStatus = MyDeviceAlarmStatus(
    notification: NotificationAuthorizationStatus.authorized,
    timeSensitiveAllowed: true,
    alarmKit: AlarmKitAuthorizationStatus.notSupported,
  );

  static const deniedStatus = MyDeviceAlarmStatus(
    notification: NotificationAuthorizationStatus.denied,
    timeSensitiveAllowed: false,
    alarmKit: AlarmKitAuthorizationStatus.denied,
  );

  static const timeSensitiveOffStatus = MyDeviceAlarmStatus(
    notification: NotificationAuthorizationStatus.authorized,
    timeSensitiveAllowed: false,
    alarmKit: AlarmKitAuthorizationStatus.notSupported,
  );

  static const notDeterminedStatus = MyDeviceAlarmStatus(
    notification: NotificationAuthorizationStatus.notDetermined,
    timeSensitiveAllowed: false,
    alarmKit: AlarmKitAuthorizationStatus.notDetermined,
  );

  @override
  Future<MyDeviceAlarmStatus> loadStatus() async {
    loadCalls++;
    return status;
  }

  @override
  Future<bool> isAndroidReady() async => true;

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalls++;
    return true;
  }
}

Future<PackageInfo> fakePackageInfo() async => PackageInfo(
  appName: 'after30',
  packageName: 'com.after30.app',
  version: '1.2.3',
  buildNumber: '45',
);

/// 가짜 의존성을 주입한 [MyPage].
MyPage buildMyPage({
  required FakeMyProfileService profile,
  FakeDeviceAlarmGateway? device,
  Future<String?> Function()? kakaoImage,
  Future<void> Function(BuildContext)? logout,
  Future<void> Function(BuildContext)? deleteAccount,
}) {
  return MyPage(
    profileService: profile,
    deviceAlarm: device ?? FakeDeviceAlarmGateway(),
    loadPackageInfo: fakePackageInfo,
    kakaoProfileImageLoader: kakaoImage ?? () async => null,
    logout: logout,
    deleteAccount: deleteAccount,
  );
}

ThemeData themeFor(TargetPlatform platform) =>
    AppTheme.build().copyWith(platform: platform);

/// 800x2400(dpr 1)의 키 큰 화면. 목록이 지연 빌드(sliver)라 기본 800x600에서는
/// 아래쪽 행이 아예 만들어지지 않으므로 대부분의 테스트에서 쓴다.
void useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required TargetPlatform platform,
  double textScale = 1.0,
  bool tallView = true,
}) async {
  if (tallView) useTallView(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// 마이 탭 자리에 [myTab]을 넣은 [AppShell].
Future<void> pumpShellWith(
  WidgetTester tester,
  Widget myTab, {
  required TargetPlatform platform,
  int initialIndex = AppShellTab.my,
  bool tallView = true,
}) async {
  if (tallView) useTallView(tester);
  final builders = List<AppShellPageBuilder>.generate(
    AppShellTab.count,
    (i) => (context, args) => Scaffold(body: Center(child: Text('stub-$i'))),
  );
  builders[AppShellTab.my] = (context, args) => myTab;
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(platform),
      home: AppShell(initialIndex: initialIndex, pageBuilders: builders),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// 편집 화면을 인자와 함께 push한 상태로 만든다. pop 결과는 [result]에 담긴다.
Future<void> pumpEditPage(
  WidgetTester tester, {
  required TargetPlatform platform,
  required FakeMyProfileService profile,
  FakeMyUserService? users,
  Map<String, Object?>? args,
  ValueNotifier<Object?>? result,
}) async {
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(platform),
      navigatorKey: navKey,
      home: const Scaffold(body: SizedBox()),
    ),
  );
  navKey.currentState!
      .push<Object?>(
        MaterialPageRoute<Object?>(
          settings: RouteSettings(
            name: '/my-info-edit',
            arguments:
                args ??
                {
                  'name': '홍길동',
                  'phoneNumber': '010-1234-5678',
                  'email': 'a@b.com',
                  'gender': '남',
                  'isKakaoLoggedIn': false,
                  'provider': 'email',
                },
          ),
          builder: (_) => MyInfoEditPage(
            profileService: profile,
            userService: users ?? FakeMyUserService(),
          ),
        ),
      )
      .then((v) => result?.value = v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget buildInfoPage(FakeMyProfileService profile) => MyInfoPage(
  profileService: profile,
  userService: FakeMyUserService(),
);

Widget buildEditPage(FakeMyProfileService profile) => MyInfoEditPage(
  profileService: profile,
  userService: FakeMyUserService(),
);
