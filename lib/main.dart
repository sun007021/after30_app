import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/app/app_routes.dart';
import 'package:after30/core/auth/session_bootstrapper.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/models/medicine_alarm.dart';
import 'package:after30/core/storage/onboarding_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:after30/services/notifications/fcm_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
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
      theme: AppTheme.build(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      initialRoute: '/startup',
      // 대부분의 라우트 이름 테이블은 lib/app/app_routes.dart에서
      // 공유한다(PR #31 B1). AppShell 탭 Navigator의 onGenerateRoute도
      // 같은 맵을 쓴다. `/startup`, `/fullscreen_alarm`은 이 파일이
      // 소유한 위젯(W3/W4가 계속 작업 중)이라 여기서 직접 넘긴다(N3).
      routes: buildAppRoutes(
        startup: (context) => const StartupPage(),
        fullscreenAlarm: (context) => const FullscreenAlarmPlaceholder(),
      ),
    );
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
          // 앱이 알림으로 콜드 스타트된 경우, 잠금이 풀려 있어도 풀스크린
          // 알람 화면을 보여준다(잠금 여부와 무관하게 사용자가 알림으로
          // 앱을 열었다는 사실 자체가 이동 의도를 나타낸다).
          if (isFs) {
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

      // 토큰 리프레시 → 사용자 ID 통합(구 카카오ID/이메일 폴백 → 백엔드
      // ID) → 알람 네임스페이스 마이그레이션 → 재스케줄 → FCM 동기화까지는
      // SessionBootstrapper가 공통으로 처리한다(plan §6 W3a 1·2항, login.dart/
      // email_login_page.dart와 동일한 경로).
      final restored = await SessionBootstrapper.restore();
      if (!mounted) return;
      if (restored) {
        await OnboardingStore.setCompleted();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        await _goToOnboardingOrLogin();
      }
    } catch (_) {
      if (!mounted) return;
      await _goToOnboardingOrLogin();
    }
  }

  Future<void> _goToOnboardingOrLogin() async {
    final seenOnboarding = await OnboardingStore.isCompleted();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(seenOnboarding ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SvgPicture.asset(
          'assets/images/mainicon.svg',
          width: 80,
          height: 80,
        ),
      ),
    );
  }
}
