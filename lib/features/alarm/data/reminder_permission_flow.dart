import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:after30/core/design/components/app_dialogs.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/services/notifications/fcm_service.dart';

/// 알림 권한 요청 시점을 HIG에 맞게 조정한다(plan §1.3, §6 W4 2항).
///
/// 기존에는 `AlarmService.initialize()`가 앱 실행 즉시(온보딩보다도 전)
/// 권한을 요청했다. 이제 두 시점으로 나눈다.
/// - [ensureRequestedAfterLogin]: 로그인 후 앱 셸에 처음 들어왔을 때 1회.
///   Android는 기존과 동작이 사실상 같다(그냥 요청 시점만 늦춰짐).
/// - [requestWithRationale]: 첫 약 등록 등 맥락이 있는 시점에 W5가 호출.
///   사전 설명 알럿 → 시스템 권한 요청 → (iOS 26+) AlarmKit 권한까지.
class ReminderPermissionFlow {
  ReminderPermissionFlow._();

  static const String _kRequestedAfterLoginKey =
      'reminder_permission_requested_after_login';

  /// 로그인 직후 앱 셸 진입 시 1회만 호출한다(`app_shell.dart` initState).
  static Future<void> ensureRequestedAfterLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kRequestedAfterLoginKey) ?? false) return;

    // Android/iOS 공통으로 로그인 직후 1회 시스템 알림 권한을 요청한다
    // (리뷰 m1 — 예전에는 iOS만 건너뛰고 첫 약 등록까지 미뤄서, 약을
    // 등록하지 않는 사용자는 영영 알림을 못 받았다).
    try {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    } catch (_) {
      // 권한 다이얼로그를 띄울 수 없는 상황(테스트 등)은 조용히 무시한다.
    }

    // 플래그는 요청이 끝난 뒤에 세운다(리뷰 m1 — 요청 도중 예외가 나거나
    // 프로세스가 죽으면 다음 진입 때 다시 시도할 수 있어야 한다).
    await prefs.setBool(_kRequestedAfterLoginKey, true);
  }

  /// 첫 약 등록 직전 등 맥락이 있는 시점에 호출한다(W5). 사전 설명 알럿에
  /// 동의하면 시스템 알림 권한을 요청하고, iOS 26+에서는 AlarmKit 권한도
  /// 함께 요청한다. 사용자가 사전 설명을 취소하면 아무 것도 요청하지 않고
  /// false를 반환한다.
  static Future<bool> requestWithRationale(BuildContext context) async {
    final proceed = await showAppConfirm(
      context: context,
      title: '알림 권한이 필요해요',
      message: '복약 시간을 놓치지 않도록 알림을 보내드릴게요. 다음 화면에서 알림을 허용해주세요.',
      cancelLabel: '나중에',
      confirmLabel: '허용하기',
    );
    if (!proceed) return false;

    var granted = false;
    if (Platform.isIOS) {
      // iOS는 FCM이 쓰는 시스템 권한(UNUserNotificationCenter)과 로컬
      // 알림 권한이 같은 다이얼로그라 Firebase 쪽 요청 하나로 충분하다
      // (plan §6 W4 6항). 리뷰 M11: 이어서
      // `AwesomeNotifications().requestPermissionToSendNotifications()`를
      // "이미 결정된 상태를 다시 읽기만 한다"는 의도로 호출했었는데,
      // 실제로는 방금 거부된 직후 iOS 설정 앱을 열어버려서 완전히
      // 제거했다.
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        // APNs 토큰을 기다리느라 이 화면 흐름을 막지 않는다(리뷰 M7).
        // 백엔드 동기화는 실패해도 다음 토큰 갱신/재시도 때 다시 된다.
        unawaited(FcmService.syncTokenToBackend());
      } catch (_) {
        granted = false;
      }
    } else {
      try {
        granted = await AwesomeNotifications().requestPermissionToSendNotifications();
      } catch (_) {
        granted = false;
      }
    }

    if (Platform.isIOS) {
      final alarmKit = AlarmService.alarmKitScheduler;
      if (alarmKit != null) {
        final status = await alarmKit.authorizationStatus();
        if (status == AlarmKitAuthorizationStatus.notDetermined) {
          await alarmKit.requestAuthorization();
        }
      }
    }

    return granted;
  }
}
