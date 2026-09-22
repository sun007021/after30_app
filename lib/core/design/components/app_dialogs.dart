import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// 액션 시트/확인 알럿에 쓰이는 개별 액션 정의.
class AppActionSheetAction<T> {
  const AppActionSheetAction({required this.label, required this.value, this.destructive = false});

  final String label;
  final T value;
  final bool destructive;
}

/// 확인 버튼 하나만 있는 알럿(정보성 안내).
Future<void> showAppAlert({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '확인',
}) async {
  if (isCupertino(context)) {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x80C8C8C8),
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );
}

/// 확인/취소 2개 선택지가 있는 알럿. 파괴적 액션(삭제, 탈퇴 등)이면
/// [destructive]를 true로 설정해 iOS에서 빨간 텍스트로 표시한다.
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = '취소',
  String confirmLabel = '완료',
  bool destructive = false,
}) async {
  if (isCupertino(context)) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x80C8C8C8),
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceMuted,
                    foregroundColor: AppColors.label,
                    side: const BorderSide(color: Colors.transparent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: destructive ? AppColors.destructive : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 3개 이상이거나 파괴적 선택지를 담는 액션 시트.
/// iOS: [CupertinoActionSheet]. Android: 하단 시트 형태의 리스트.
Future<T?> showAppActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<AppActionSheetAction<T>> actions,
  String cancelLabel = '취소',
}) async {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        message: message != null ? Text(message) : null,
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.destructive,
              onPressed: () => Navigator.of(ctx).pop(action.value),
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    // showModalBottomSheet만 useRootNavigator 기본값이 false이므로 명시한다
    // (W10의 탭별 Navigator 위에서도 항상 최상단에 뜨도록).
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md))),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(message, style: const TextStyle(color: AppColors.secondaryLabel)),
              ),
            for (final action in actions)
              ListTile(
                title: Text(
                  action.label,
                  style: TextStyle(color: action.destructive ? AppColors.destructive : AppColors.label),
                ),
                onTap: () => Navigator.of(ctx).pop(action.value),
              ),
            ListTile(
              title: Text(cancelLabel, style: const TextStyle(color: AppColors.secondaryLabel)),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    },
  );
}

/// 제목 + 텍스트 입력 필드가 있는 알럿(예: 그룹 이름 변경).
/// 확인을 누르면 입력값을, 취소하면 null을 반환한다.
Future<String?> showAppTextInputAlert({
  required BuildContext context,
  required String title,
  String? message,
  String? initialValue,
  String cancelLabel = '취소',
  String confirmLabel = '확인',
  int? maxLength,
  TextInputType? keyboardType,
}) {
  final cupertino = isCupertino(context);
  final body = _TextInputAlertBody(
    title: title,
    message: message,
    initialValue: initialValue,
    cancelLabel: cancelLabel,
    confirmLabel: confirmLabel,
    maxLength: maxLength,
    keyboardType: keyboardType,
    cupertino: cupertino,
  );

  if (cupertino) {
    return showCupertinoDialog<String>(context: context, builder: (ctx) => body);
  }

  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x80C8C8C8),
    barrierDismissible: false,
    builder: (ctx) => body,
  );
}

/// [showAppTextInputAlert]의 본문. [TextEditingController]를 이 위젯이
/// 직접 소유하고 dispose하여 누수를 막는다(예전에는 함수 스코프에서
/// 만든 컨트롤러를 다이얼로그가 닫힌 뒤에도 정리하지 않았다).
class _TextInputAlertBody extends StatefulWidget {
  const _TextInputAlertBody({
    required this.title,
    required this.message,
    required this.initialValue,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.maxLength,
    required this.keyboardType,
    required this.cupertino,
  });

  final String title;
  final String? message;
  final String? initialValue;
  final String cancelLabel;
  final String confirmLabel;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool cupertino;

  @override
  State<_TextInputAlertBody> createState() => _TextInputAlertBodyState();
}

class _TextInputAlertBodyState extends State<_TextInputAlertBody> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cupertino) {
      return CupertinoAlertDialog(
        title: Text(widget.title),
        content: Column(
          children: [
            if (widget.message != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.message!)),
            CupertinoTextField(
              controller: _controller,
              maxLength: widget.maxLength,
              keyboardType: widget.keyboardType,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: Text(widget.cancelLabel)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text(widget.confirmLabel),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.message!)),
          TextField(
            controller: _controller,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            autofocus: true,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.label,
                  side: const BorderSide(color: Colors.transparent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(widget.cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
