import 'package:flutter/material.dart';
import 'package:after30/core/design/components/app_dialogs.dart';

/// 복용 완료/취소 같은 확인이 필요한 상황에서 사용하는 더블 체크 다이얼로그.
///
/// 공개 API(`show`/`showSingle`의 시그니처와 반환값)는 그대로 유지하고,
/// 내부 구현만 [showAppConfirm]/[showAppAlert]에 위임한다. 그 결과 iOS에서는
/// CupertinoAlertDialog로, Android에서는 기존과 동일한 AlertDialog 외형으로
/// 표시된다.
class DoubleCheckDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelLabel = '취소',
    String confirmLabel = '완료',
  }) {
    return showAppConfirm(
      context: context,
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    );
  }

  static Future<void> showSingle({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = '확인',
  }) {
    return showAppAlert(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
  }
}
