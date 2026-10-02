import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/utils/responsive.dart';

/// 전화번호가 없는 사용자에게 가족 탭 상단에 보여주는 닫을 수 있는 안내
/// 배너(plan §2 D11). 강제 모달 대신, 등록 시점을 사용자가 고르게 한다.
class FamilyPhoneBanner extends StatelessWidget {
  const FamilyPhoneBanner({
    super.key,
    required this.onRegister,
    required this.onDismiss,
  });

  final VoidCallback onRegister;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        // 배경이 연한 파랑(#EAF2FF)인 가족 탭 위에서도 카드 경계가 보이도록
        // 흰 카드 + 브랜드 테두리를 쓴다.
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: cupertino
              ? RoundedSuperellipseBorder(
                  borderRadius: AppRadius.borderRadius(AppRadius.sm),
                  side: const BorderSide(color: AppColors.primary, width: 1),
                )
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.primary, width: 1),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '가족이 나를 초대하려면 전화번호가 필요해요',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.label,
                      height: 1.3,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRegister,
                    // 탭 영역은 최소 44pt(HIG)로 확보한다.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '등록하기',
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(context, 13),
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
