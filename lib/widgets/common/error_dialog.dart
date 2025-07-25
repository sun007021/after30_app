// 이 위젯은 login.dart(로그인 화면) 등 앱 전역에서 공통적으로 사용됩니다.
import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? detail;

  const ErrorDialog({
    super.key,
    this.title = '오류',
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail!,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
