import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'package:dio/dio.dart';

/// 계정 탈퇴 다이얼로그 관련 함수들
class DeleteAccountDialog {
  static Future<void> show(BuildContext context) async {
    // 현재 카카오 세션이 있는지 확인
    bool hasKakaoSession = false;
    try {
      await UserApi.instance.accessTokenInfo();
      hasKakaoSession = true;
    } catch (_) {
      hasKakaoSession = false;
    }

    if (hasKakaoSession) {
      await _showKakaoDeleteDialog(context);
    } else {
      await _showEmailDeleteDialog(context);
    }
  }

  static Future<void> _showKakaoDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '계정 탈퇴',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          content: const Text('계정 탈퇴를 위해 카카오 인증이 필요합니다. 계속하시겠습니까?'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF111111),
                      side: const BorderSide(color: Colors.transparent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1963FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      bool kakaoTalkInstalled = await isKakaoTalkInstalled();
      OAuthToken? token;
      if (kakaoTalkInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      // 백엔드에 삭제 요청
      await MyProfileService().deleteAccountWithKakao(token.accessToken);
      // 카카오 연결 해제 시도 (실패해도 무시)
      try {
        await UserApi.instance.unlink();
      } catch (_) {}
      if (context.mounted) {
        await AuthService.logout(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, '계정 탈퇴 중 오류가 발생했습니다: $e');
    }
  }

  static Future<void> _showEmailDeleteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canSubmit = controller.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '계정 탈퇴',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('계정 탈퇴를 위해 비밀번호를 입력해주세요.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '비밀번호',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF1963FF),
                          width: 1.2,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF111111),
                          side: const BorderSide(color: Colors.transparent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () => Navigator.of(ctx).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1963FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD3DEFF),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('탈퇴'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    final password = controller.text;
    if (password.isEmpty) return;
    try {
      await MyProfileService().deleteAccountWithPassword(password);
      if (context.mounted) {
        await AuthService.logout(context);
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      final status = e.response?.statusCode;
      final message = status == 401
          ? '비밀번호가 올바르지 않습니다.'
          : '계정 탈퇴 중 오류가 발생했습니다.';
      _showErrorDialog(context, message);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, '계정 탈퇴 중 오류가 발생했습니다: $e');
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('탈퇴 실패'),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF111111),
                    side: const BorderSide(color: Colors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1963FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
