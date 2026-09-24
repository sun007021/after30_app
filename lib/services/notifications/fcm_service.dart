import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/settings_store.dart';

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

    if (Platform.isIOS) {
      // 앱이 포그라운드에 있을 때도 시스템이 배너/뱃지/사운드를 직접
      // 보여주게 한다(plan §6 W4 6항). 이걸 설정하면 아래에서 직접
      // 로컬 알림을 만들 필요가 없어 중복 표시를 막을 수 있다.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 초기 진입 경로(알림 클릭으로 cold start)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initialMessage: ${initialMessage.messageId}');
    }

    // 포그라운드 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final allowPush = await MySettingsStore.getAllowPushNotifications();
      if (!allowPush) return;

      final title = message.notification?.title ?? 'FCM';
      final body = message.notification?.body ?? '(본문 없음)';
      debugPrint('FCM(포그라운드) ${message.messageId}: $title - $body');

      // iOS는 setForegroundNotificationPresentationOptions로 시스템이
      // 이미 배너를 보여주므로, 여기서 또 로컬 알림을 만들면 두 번
      // 표시된다 - 그래서 iOS는 건너뛴다. Android는 시스템이 포그라운드
      // 알림을 자동으로 보여주지 않으므로 기존처럼 직접 만든다.
      if (Platform.isIOS) return;

      try {
        final id = DateTime.now().millisecondsSinceEpoch % 100000;
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            // 진동이 없는 푸시 전용 채널 사용
            channelKey: 'push_messages',
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

    // 토큰 로깅 및 갱신 구독. iOS는 APNs 토큰이 준비될 때까지 최대
    // 16.5초(300ms*(1+..+10)) 재시도하는데(`_waitForApnsTokenIfNeeded`),
    // 이걸 기다리면 콜드 런치가 그만큼 늦어진다(리뷰 M7) — 로깅용일
    // 뿐이니 기다리지 않는다.
    unawaited(logToken());
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM 토큰 갱신: $newToken');
      final allowPush = await MySettingsStore.getAllowPushNotifications();
      if (!allowPush) return;
      try {
        await MyProfileService().updateFcmToken(newToken);
      } catch (e) {
        debugPrint('FCM 토큰 갱신 백엔드 전송 실패: $e');
      }
    });
  }

  /// iOS는 APNs 토큰이 준비되기 전에 `getToken()`을 호출하면 실패하거나
  /// null을 반환할 수 있다(plan §6 W4 6항 "APNs 토큰 타이밍" 리스크).
  /// 짧은 간격으로 재시도해 APNs 토큰이 생길 때까지 기다린다. Android는
  /// 즉시 통과한다.
  static Future<void> _waitForApnsTokenIfNeeded() async {
    if (!Platform.isIOS) return;
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) return;
      } catch (e) {
        debugPrint('APNs 토큰 조회 실패(재시도 $attempt): $e');
      }
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    debugPrint('APNs 토큰을 끝내 받지 못했습니다 - getToken이 실패할 수 있습니다.');
  }

  static Future<String?> _getTokenSafely() async {
    await _waitForApnsTokenIfNeeded();
    return FirebaseMessaging.instance.getToken();
  }

  static Future<void> logToken() async {
    try {
      final token = await _getTokenSafely();
      if (token != null) {
        debugPrint('FCM 토큰: $token');
      } else {
        debugPrint('FCM 토큰을 가져오지 못했습니다.');
      }
    } catch (e) {
      debugPrint('FCM 토큰 조회 실패: $e');
    }
  }

  static Future<void> syncTokenToBackend() async {
    try {
      final allowPush = await MySettingsStore.getAllowPushNotifications();
      if (!allowPush) return;

      final token = await _getTokenSafely();
      if (token == null) {
        debugPrint('FCM 토큰이 없어 백엔드 전송을 건너뜁니다.');
        return;
      }
      await MyProfileService().updateFcmToken(token);
      debugPrint('FCM 토큰을 백엔드로 동기화했습니다.');
    } catch (e) {
      debugPrint('FCM 토큰 백엔드 동기화 실패: $e');
    }
  }

  static Future<void> setPushEnabled(bool enabled) async {
    try {
      if (enabled) {
        await syncTokenToBackend();
      } else {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      debugPrint('푸시 알림 설정 변경 실패: $e');
    }
  }
}
