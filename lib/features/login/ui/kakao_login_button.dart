// 이 위젯은 login.dart(로그인 화면)의 로그인 옵션 시트에서 사용됩니다.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/app_platform.dart';
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
    if (isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  /// iOS: 높이 50 캡슐(`signup_intro.dart`의 iOS 카카오 버튼과 같은 모양).
  /// 로딩 중에는 탭을 무시하고, 큰 글자에서는 말줄임으로 넘침을 막는다.
  Widget _buildCupertino(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: '카카오로 시작하기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: const ShapeDecoration(
            color: Color(0xFFFEE500),
            shape: StadiumBorder(),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const CupertinoActivityIndicator(color: Color(0xFF191919))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/kakao_chat.svg',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        '카카오로 시작하기',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF191919),
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Android: 기존 외형을 그대로 유지한다.
  Widget _buildMaterial(BuildContext context) {
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
