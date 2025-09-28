// 이 위젯은 home.dart(홈 화면)에서 사용됩니다.
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;

  const HomeAppBar({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('식후 30분'),
      backgroundColor: Colors.yellow[600],
      foregroundColor: Colors.black,
      actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
