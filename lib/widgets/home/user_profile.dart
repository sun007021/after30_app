// 이 위젯은 home_content.dart(홈 화면)에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

class UserProfile extends StatelessWidget {
  final User? user;

  const UserProfile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          '${user!.kakaoAccount?.profile?.nickname ?? '사용자'}님',
          style: TextStyle(fontSize: 20, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        if (user!.kakaoAccount?.profile?.profileImageUrl != null)
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(
              user!.kakaoAccount!.profile!.profileImageUrl!,
            ),
          ),
      ],
    );
  }
}
