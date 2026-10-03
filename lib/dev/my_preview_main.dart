// 디버그 전용 프리뷰 엔트리포인트(plan §6 W9 검증 절차).
//
// 마이페이지/내 정보/내 정보 수정은 로그인된 백엔드 세션과 기기 권한이
// 있어야 실제 모습을 볼 수 있는데, 네트워크 없이 시뮬레이터에서 iOS 스타일을
// 확인하기 위해 가짜 서비스를 주입해 [AppShell] 안에 실제 화면을 띄운다.
// `flutter build ios --simulator`는 Xcode 26.6 + Flutter 3.38.3 조합에서
// lipo 오류로 실패하므로(plan §3 각주), 다음처럼 실행한다.
//
//   flutter run -d <simulator> -t lib/dev/my_preview_main.dart \
//     --dart-define=SCENE=mypage|denied|info|edit --no-resident
//
// SCENE: mypage(기본, 권한 허용), denied(알림/AlarmKit 거부), info(내 정보,
// 번호 미등록), edit(내 정보 수정). 릴리스 빌드 진입점이 아니므로 main.dart에서
// import하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

const _scene = String.fromEnvironment('SCENE', defaultValue: 'mypage');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 셸이 처음 진입할 때 띄우는 시스템 알림 권한 다이얼로그가 스크린샷을
  // 가리지 않게, 이미 요청한 것으로 표시해 둔다(프리뷰 전용).
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('reminder_permission_requested_after_login', true);
  runApp(const _MyPreviewApp());
}

class _PreviewProfileService extends MyProfileService {
  @override
  Future<MyProfile> getMyProfile() async => MyProfile(
        name: '김식후',
        email: 'after30@example.com',
        gender: '여',
        allowMarketing: false,
        provider: 'kakao',
        // info 장면에서는 번호 미등록 행을 보여준다.
        phoneNumber: _scene == 'info' || _scene == 'mypage-unregistered' ? null : '010-1234-5678',
      );
}

class _PreviewUserService extends UserService {
  @override
  Future<bool> isPhoneDuplicate(String phoneNumber) async => false;
}

class _PreviewDeviceAlarm extends MyDeviceAlarmGateway {
  const _PreviewDeviceAlarm();

  @override
  Future<MyDeviceAlarmStatus> loadStatus() async {
    if (_scene == 'denied') {
      return const MyDeviceAlarmStatus(
        notification: NotificationAuthorizationStatus.denied,
        timeSensitiveAllowed: false,
        alarmKit: AlarmKitAuthorizationStatus.denied,
      );
    }
    return const MyDeviceAlarmStatus(
      notification: NotificationAuthorizationStatus.authorized,
      timeSensitiveAllowed: true,
      alarmKit: AlarmKitAuthorizationStatus.authorized,
    );
  }
}

Future<PackageInfo> _previewPackageInfo() async => PackageInfo(
      appName: 'after30',
      packageName: 'com.after30.app',
      version: '1.1.0',
      buildNumber: '18',
    );

class _MyPreviewApp extends StatelessWidget {
  const _MyPreviewApp();

  @override
  Widget build(BuildContext context) {
    final profile = _PreviewProfileService();
    final users = _PreviewUserService();

    Widget tab;
    switch (_scene) {
      case 'info':
        tab = MyInfoPage(profileService: profile, userService: users);
      case 'edit':
        tab = Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: {
                'name': '김식후',
                'phoneNumber': '010-1234-5678',
                'email': 'after30@example.com',
                'gender': '여',
                'isKakaoLoggedIn': true,
                'provider': 'kakao',
              },
            ),
            builder: (_) => MyInfoEditPage(profileService: profile, userService: users),
          ),
        );
      default:
        tab = MyPage(
          profileService: profile,
          deviceAlarm: const _PreviewDeviceAlarm(),
          loadPackageInfo: _previewPackageInfo,
          kakaoProfileImageLoader: () async => null,
        );
    }

    return MaterialApp(
      title: '마이페이지 프리뷰',
      theme: AppTheme.build(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      debugShowCheckedModeBanner: false,
      home: AppShell(
        initialIndex: AppShellTab.my,
        pageBuilders: [
          (context, args) => const _StubTabPage(),
          (context, args) => const _StubTabPage(),
          (context, args) => const _StubTabPage(),
          (context, args) => const _StubTabPage(),
          (context, args) => tab,
        ],
      ),
    );
  }
}

class _StubTabPage extends StatelessWidget {
  const _StubTabPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
