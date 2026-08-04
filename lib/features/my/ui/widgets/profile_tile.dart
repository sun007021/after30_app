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
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: Responsive.responsivePaddingLTRB(context, 10, 15, 10, 15),
          child: Row(
            children: [
              CircleAvatar(
                radius: Responsive.responsiveValue(context, 20),
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
                    fontSize: Responsive.responsiveFontSize(context, 13),
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: Responsive.responsiveIconSize(context, 32),
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
