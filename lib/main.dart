import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/app/app_routes.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:after30/services/notifications/fcm_service.dart';
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
      // 라우트 이름 테이블은 lib/app/app_routes.dart에서 공유한다(PR #31
      // B1). AppShell 탭 Navigator의 onGenerateRoute도 같은 맵을 쓴다.
      routes: appRoutes,
    );
  }
}
