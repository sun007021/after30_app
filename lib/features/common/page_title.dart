import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/utils/responsive.dart';

/// 섹션 제목 텍스트(plan §6 W10 7항).
///
/// `AppNavBar`처럼 화면 상단 전체를 차지하는 내비게이션 바가 아니라, 홈
/// 화면(`home_content.dart`) 안에서 스크롤되는 콘텐츠 사이에 놓이는 인라인
/// 섹션 헤더이므로, `AppNavBar`를 그대로 끼워 넣으면 레이아웃이 깨진다.
/// 대신 디자인 시스템 타이포그래피 토큰([AppTypography])을 재사용해 iOS/
/// Android 스타일을 일관되게 맞추되, Android는 기존 텍스트 스타일과
/// 픽셀 단위로 동일하게 유지한다.
class PageTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? margin;

  const PageTitle({super.key, required this.title, this.margin});

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return Padding(
      padding:
          margin ?? Responsive.responsivePaddingLTRB(context, 20, 24, 20, 8),
      child: AppTypography.clampTextScale(
        child: Text(
          title,
          style: cupertino
              ? AppTypography.title.copyWith(fontSize: 20, fontWeight: FontWeight.w700)
              : TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 20),
                  fontWeight: FontWeight.w700,
                ),
        ),
      ),
    );
  }
}
