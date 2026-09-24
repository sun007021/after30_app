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
    await prefs.setBool(_kRequestedAfterLoginKey, true);

    // Android는 기존과 동일하게(그냥 시점만 콜드 런치 → 로그인 직후로
    // 늦춘 것) 바로 시스템 권한을 요청한다. iOS는 여기서 바로 요청하지
    // 않고 첫 약 등록 시점([requestWithRationale])까지 기다린다 —
    // Apple HIG는 권한 요청 전에 맥락(사전 설명)을 요구한다.
    if (Platform.isAndroid) {
      try {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      } catch (_) {
        // 권한 다이얼로그를 띄울 수 없는 상황(테스트 등)은 조용히 무시한다.
      }
    }
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
      // 알림 권한이 같은 다이얼로그다. Firebase 쪽에서 먼저 요청 결과를
      // 확인한 뒤(plan §6 W4 6항), awesome_notifications 쪽은 이미 결정된
      // 상태를 다시 읽기만 한다(두 번째 다이얼로그가 뜨지 않는다).
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        await AwesomeNotifications().requestPermissionToSendNotifications();
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
