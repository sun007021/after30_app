import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';
import 'package:after30/utils/responsive.dart';

/// 프로필 타일 위젯
///
/// iOS: inset grouped 목록 한 행(아바타 + 이름 + 셰브론). Android: 기존
/// 카드 타일 외형 그대로(실패 상태일 때만 문구가 바뀐다).
class ProfileTile extends StatelessWidget {
  final String nickname;
  final String? imageUrl;
  final VoidCallback onTap;

  /// 프로필 조회가 실패한 상태. true면 이름 대신 오류 문구를 보여주고
  /// 탭하면 [onTap] 대신 [onRetry]를 호출한다.
  final bool loadFailed;
  final VoidCallback? onRetry;

  /// iOS 보조 문구(예: "전화번호 미등록").
  final String? subtitle;

  const ProfileTile({
    super.key,
    required this.nickname,
    this.imageUrl,
    required this.onTap,
    this.loadFailed = false,
    this.onRetry,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final title = loadFailed ? '프로필을 불러오지 못했어요' : '$nickname님의 정보';
    final handler = loadFailed ? (onRetry ?? onTap) : onTap;

    if (isCupertino(context)) {
      return AppGroupedSection(
        children: [
          AppListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            ),
            leadingWidth: 44,
            title: title,
            subtitle: loadFailed ? '탭하여 다시 시도' : subtitle,
            showChevron: !loadFailed,
            onTap: handler,
          ),
        ],
      );
    }

    return CardContainer(
      child: InkWell(
        onTap: handler,
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
                  title,
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
