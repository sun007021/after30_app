import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

/// iOS 인증 계열 화면(이메일 로그인/회원가입/약관/가입 안내)의 공통 틀.
///
/// 파란 헤더 대신 흰 배경 + Large Title 스타일 제목을 쓰고, CTA는 스크롤
/// 영역 밖 하단에 고정한다. [Scaffold]가 키보드 높이만큼 본문을 줄이므로
/// CTA는 항상 키보드 바로 위에 남고, 홈 인디케이터 영역은 [SafeArea]가
/// 처리한다. Android는 이 위젯을 쓰지 않고 기존 화면 구성을 유지한다.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.cta,
    this.backgroundColor = AppColors.surface,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// 하단에 고정되는 CTA(보통 [AppButton]).
  final Widget? cta;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 가입 직후처럼 루트에 이 화면만 남은 경우(pop 불가)에는 눌러도 아무 일도
            // 없는 뒤로 버튼을 숨기고, 같은 높이의 빈 자리를 둬 배치를 유지한다.
            if (ModalRoute.of(context)?.canPop ?? false)
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(52, 44),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(CupertinoIcons.back, color: AppColors.label, size: 26),
                ),
              )
            else
              const SizedBox(height: 44),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 15, color: AppColors.secondaryLabel),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ...children,
                  ],
                ),
              ),
            ),
            if (cta != null) Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: cta),
          ],
        ),
      ),
    );
  }
}
