import 'package:flutter/material.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';
import 'package:after30/utils/responsive.dart';

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
          padding: EdgeInsets.symmetric(
            vertical: Responsive.responsiveValue(context, 12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: Responsive.responsiveValue(context, 22),
                backgroundColor: Colors.grey.shade300,
                backgroundImage: imageUrl != null
                    ? NetworkImage(imageUrl!)
                    : null,
              ),
              SizedBox(width: Responsive.responsiveWidth(context, 12)),
              Expanded(
                child: Text(
                  '$nickname님의 정보',
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: Responsive.responsiveIconSize(context, 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
