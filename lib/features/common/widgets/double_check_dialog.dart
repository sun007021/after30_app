import 'package:flutter/material.dart';

/// 복용 완료/취소 같은 확인이 필요한 상황에서 사용하는 더블 체크 다이얼로그
class DoubleCheckDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelLabel = '취소',
    String confirmLabel = '완료',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80C8C8C8),
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF111111),
                      side: const BorderSide(color: Colors.transparent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      backgroundColor: const Color(0xFF1963FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  static Future<void> showSingle({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = '확인',
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x80C8C8C8),
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1963FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}
