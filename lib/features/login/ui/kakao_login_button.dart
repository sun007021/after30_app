// 이 위젯은 login.dart(로그인 화면)의 로그인 옵션 시트에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/utils/responsive.dart';

class KakaoLoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const KakaoLoginButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: Responsive.responsiveValue(context, 48),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF191919),
          disabledBackgroundColor: const Color(0xFFFEE500),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              Responsive.responsiveValue(context, 12),
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF191919)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/kakao_chat.svg',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '카카오로 시작하기',
                    style: TextStyle(
                      color: const Color(0xFF191919),
                      fontWeight: FontWeight.w700,
                      fontSize: Responsive.responsiveFontSize(context, 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
