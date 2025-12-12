import 'package:flutter/material.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';

/// 프로필 타일 위젯
class ProfileTile extends StatelessWidget {
  final String nickname;
  final String? imageUrl;
  final VoidCallback onTap;

  const ProfileTile({
    super.key,
    required this.nickname,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: imageUrl != null
                    ? NetworkImage(imageUrl!)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$nickname님의 정보',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
