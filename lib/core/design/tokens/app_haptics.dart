import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/core/design/app_platform.dart';

/// 햅틱 피드백 헬퍼.
///
/// 기존 코드는 어디에서도 [HapticFeedback]을 쓰지 않았으므로, Android
/// 화면의 동작을 바꾸지 않기 위해 Android에서는 항상 no-op이다. iOS에서만
/// 스펙(§4.3)에 정의된 상황(토글/스냅/탭 전환은 selection, 복용 완료
/// 성공은 success, 삭제 확정은 warning)에 맞춰 호출한다.
class AppHaptics {
  AppHaptics._();

  /// 토글, 피커 스냅, 탭 전환, 버튼 눌림에 사용.
  static void selection(BuildContext context) {
    if (!isCupertino(context)) return;
    HapticFeedback.selectionClick();
  }

  /// 성공 동작(예: 복용 완료 슬라이드 성공)에 사용.
  static void success(BuildContext context) {
    if (!isCupertino(context)) return;
    HapticFeedback.mediumImpact();
  }

  /// 경고/파괴적 동작 확정(예: 삭제 확정)에 사용.
  static void warning(BuildContext context) {
    if (!isCupertino(context)) return;
    HapticFeedback.heavyImpact();
  }
}
