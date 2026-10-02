import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/utils/responsive.dart';

class FamilyInvitationBanner extends StatelessWidget {
  final FamilyInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isProcessing;

  const FamilyInvitationBanner({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    final inviter = invitation.inviterName?.trim();
    final groupName = invitation.groupName?.trim();
    if (isCupertino(context)) return _buildCupertino(context, inviter, groupName);

    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 20, 0, 20, 12),
      child: Container(
        padding: Responsive.responsivePaddingLTRB(context, 14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFA4A4A4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/images/fam_group.svg',
                  width: Responsive.responsiveValue(context, 46),
                  height: Responsive.responsiveValue(context, 46),
                  fit: BoxFit.contain,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'N',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: Responsive.responsiveWidth(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '그룹 초대가 왔어요!',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 4)),
                  Text(
                    inviter != null && inviter.isNotEmpty && groupName != null
                        ? '$inviter님이 \'$groupName\' 그룹에 초대했어요.'
                        : '가족 그룹 초대가 도착했습니다.',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 12),
                      color: const Color(0xFF727272),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.responsiveWidth(context, 8)),
            Column(
              children: [
                _ActionButton(
                  label: '수락하기',
                  filled: true,
                  onTap: isProcessing ? null : onAccept,
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 6)),
                _ActionButton(
                  label: '거절하기',
                  filled: false,
                  onTap: isProcessing ? null : onDecline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on FamilyInvitationBanner {
  /// iOS: 테두리 없는 토큰 카드 + 하단 버튼 두 개(거절=tinted, 수락=filled).
  Widget _buildCupertino(BuildContext context, String? inviter, String? groupName) {
    final message = inviter != null && inviter.isNotEmpty && groupName != null
        ? '$inviter님이 \'$groupName\' 그룹에 초대했어요.'
        : '가족 그룹 초대가 도착했습니다.';
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppRadius.borderRadius(AppRadius.md),
          ),
          shadows: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '그룹 초대가 왔어요!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.label),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 15, color: AppColors.secondaryLabel, height: 1.3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '거절하기',
                    variant: AppButtonVariant.tinted,
                    size: AppButtonSize.medium,
                    onPressed: isProcessing ? null : onDecline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: '수락하기',
                    size: AppButtonSize.medium,
                    onPressed: isProcessing ? null : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.filled, this.onTap});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF235DFF);
    return Material(
      color: filled ? primaryBlue : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: filled ? null : Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : const Color(0xFF727272),
            ),
          ),
        ),
      ),
    );
  }
}
