import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 isolate에서 Firebase를 초기화해야 핸들러가 동작합니다.
  await Firebase.initializeApp();
  debugPrint('FCM(백그라운드) 메시지: ${message.messageId}');
}

class FcmService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 백그라운드 핸들러 등록 (앱 시작 전에 1회 등록 필요)
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    // 초기 진입 경로(알림 클릭으로 cold start)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initialMessage: ${initialMessage.messageId}');
    }

    // 포그라운드 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'FCM';
      final body = message.notification?.body ?? '(본문 없음)';
      debugPrint('FCM(포그라운드) ${message.messageId}: $title - $body');

      // 앱이 포그라운드일 때는 시스템이 자동 표시하지 않으므로 직접 로컬 알림 생성
      try {
        final id = DateTime.now().millisecondsSinceEpoch % 100000;
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: 'medicine_alarms',
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            displayOnForeground: true,
            displayOnBackground: true,
          ),
        );
      } catch (e) {
        debugPrint('포그라운드 알림 표시 실패: $e');
      }
    });

    // 백그라운드에서 탭하여 복귀
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
    });

    // 토큰 로깅 및 갱신 구독
    await logToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM 토큰 갱신: $newToken');
      // TODO: 필요 시 백엔드에 갱신 토큰 전송
    });
  }

  static Future<void> logToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('FCM 토큰: $token');
      } else {
        debugPrint('FCM 토큰을 가져오지 못했습니다.');
      }
    } catch (e) {
      debugPrint('FCM 토큰 조회 실패: $e');
    }
  }
}
