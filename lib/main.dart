import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:after30/screens/login/login.dart';
import 'package:after30/screens/main/home.dart';
import 'package:after30/screens/family/family_page.dart';
import 'package:flutter/widgets.dart';
import 'package:after30/services/medication_service.dart';
import 'package:after30/services/alarm_service.dart';
import 'package:after30/viewmodels/invite_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 알람 서비스 초기화
  await AlarmService().initialize();
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => InviteViewModel()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: '식후 30분',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFEE500)),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
          '/family': (context) => const FamilyPage(),
          '/fullscreen_alarm': (context) => const FullscreenAlarmPlaceholder(),
        },
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
