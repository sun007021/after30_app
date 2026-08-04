import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/login/ui/login.dart';
import 'package:after30/features/login/ui/signup_page.dart';
import 'package:after30/features/login/ui/signup_intro.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:flutter/widgets.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:after30/features/my/my_info_page.dart';
import 'package:after30/features/my/my_info_edit_page.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:after30/services/notifications/fcm_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'dart:io';
import 'package:flutter/services.dart';

// 네이티브 상태 조회 채널 및 헬퍼(전역)
const MethodChannel kNativeChannel = MethodChannel('after30/native');
Future<bool> isDeviceLocked() async {
  if (!Platform.isAndroid) return false;
  try {
    final locked = await kNativeChannel.invokeMethod<bool>('isDeviceLocked');
    return locked ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 알람 서비스 초기화
  await AlarmService().initialize();
  // FCM 서비스 초기화(포그라운드 수신 시 로컬 알림 표시)
  await FcmService.initialize();
  // 내비게이터 키 등록(알림 탭 시 라우팅)
  AlarmService.setNavigatorKey(_navigatorKey);

  KakaoSdk.init(
    nativeAppKey: '54b330c450ea6d30f52c96937e871989',
    javaScriptAppKey: 'a59e2b4c5d1e2c9b30833de3062c439f',
  );
  runApp(const MyApp());
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            '.env 파일 또는 카카오 키가 누락되었습니다.',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupAlarmListener();
  }

  void _setupAlarmListener() {
    // AlarmService의 알림 리스너 설정
    // 실제로는 MethodChannel을 사용하여 네이티브 코드와 통신해야 합니다
  }

  // FCM 관련 로직은 FcmService에서 전역 등록됩니다.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '식후 30분',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFEE500)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsPageTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsPageTransitionsBuilder(),
            TargetPlatform.macOS: NoTransitionsPageTransitionsBuilder(),
            TargetPlatform.windows: NoTransitionsPageTransitionsBuilder(),
            TargetPlatform.linux: NoTransitionsPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/startup',
      routes: {
        '/startup': (context) => const StartupPage(),
        '/login': (context) => const LoginPage(),
        '/signup-intro': (context) => const SignupIntroPage(),
        '/signup-terms': (context) => const TermsAgreementPage(),
        '/email-login': (context) => const EmailLoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/family': (context) => const FamilyPage(),
        '/fullscreen_alarm': (context) => const FullscreenAlarmPlaceholder(),
        '/my': (context) => const MyPage(),
        '/my-info': (context) => const MyInfoPage(),
        '/my-info-edit': (context) => const MyInfoEditPage(),
      },
    );
  }
}

class NoTransitionsPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

// 전체화면 알림을 위한 플레이스홀더
class FullscreenAlarmPlaceholder extends StatelessWidget {
  const FullscreenAlarmPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제로는 알람 데이터를 받아와서 FullscreenAlarm을 표시해야 합니다
    return const Scaffold(body: Center(child: Text('전체화면 알림')));
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    _attemptRefresh();
  }

  Future<void> _attemptRefresh() async {
    try {
      // FullScreen Intent로 앱이 기동된 경우에만 풀스크린 라우트로 이동
      try {
        final initialAction = await AwesomeNotifications()
            .getInitialNotificationAction();
        if (initialAction != null) {
          final payload = initialAction.payload ?? {};
          final isFs = payload['fs'] == '1';
          final locked = await isDeviceLocked();
          if (isFs && locked) {
            final alarmId = payload['alarmId'] ?? '';
            final name = payload['medicineName'] ?? '약';
            final timeStr = payload['time'] ?? '08:00';
            final day = payload['day'] ?? '월';
            final notifId = initialAction.id ?? 0;
            final hour = int.tryParse(timeStr.split(':').first) ?? 8;
            final minute = int.tryParse(timeStr.split(':').last) ?? 0;
            if (!mounted) return;
            AlarmService.showFullscreenAlarm(
              context,
              MedicineAlarm(
                id: alarmId.isEmpty ? null : alarmId,
                name: name,
                times: [TimeOfDay(hour: hour, minute: minute)],
                days: [day],
              ),
              TimeOfDay(hour: hour, minute: minute),
              day,
              notificationId: notifId,
            );
            return;
          }
        }
      } catch (_) {}

      final ok = await BackendAuthService().refreshSession();
      if (!mounted) return;
      if (ok) {
        // 저장된 사용자 ID가 있다면 네임스페이스 설정 후 재스케줄
        final userId = await UserStore.getCurrentUserId();
        AlarmService.setCurrentUserId(userId);
        await AlarmService().rescheduleAllActiveFromStorage();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
