import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:dio/dio.dart';

/// 계정 탈퇴 다이얼로그 관련 함수들.
///
/// 탈퇴 방식은 "카카오 세션이 있는지"가 아니라 백엔드 `/users/me`의
/// `provider`로 분기한다(plan §1.5 클라이언트 결합 문제, §6 W3a 3항). 예전
/// 방식은 이메일 로그인 사용자가 우연히 카카오 세션을 갖고 있으면(예: 예전에
/// 카카오로도 로그인해본 기기) 엉뚱한 탈퇴 흐름을 타는 문제가 있었다.
class DeleteAccountDialog {
  static Future<void> show(BuildContext context) async {
    final confirmed = await DoubleCheckDialog.show(
      context: context,
      title: "정말 '식후30분'을 떠나시나요?",
      message: '그동안의 모든 기록과 가족 연결 정보가 사라집니다. 정말 탈퇴하시겠습니까?',
      cancelLabel: '유지하기',
      confirmLabel: '탈퇴하기',
    );
    if (!confirmed) return;

    // 리뷰: "조회 자체가 실패"(네트워크 오류 등)와 "provider 값만 비어
    // 있음"(조회는 성공했지만 필드가 없거나 알 수 없는 값)을 구분한다.
    // 전자는 사용자의 계정 상태를 전혀 알 수 없으므로 탈퇴를 진행하지
    // 않고 오류를 안내한 뒤 중단한다. 후자만 예전 방식(카카오 세션 유무)
    // 폴백을 탄다 — App Store 5.1.1(v) 위험은 후자에서만 회피하면 된다.
    String? provider;
    bool profileFetchFailed = false;
    try {
      final profile = await MyProfileService().getMyProfile();
      provider = profile.provider;
    } catch (_) {
      profileFetchFailed = true;
    }

    if (!context.mounted) return;
    if (profileFetchFailed) {
      _showErrorDialog(context, '계정 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.');
      return;
    }
    switch (provider?.trim().toLowerCase()) {
      case 'kakao':
        await _showKakaoDeleteDialog(context);
        break;
      case 'email':
        await _showEmailDeleteDialog(context);
        break;
      case 'apple':
        // Apple 탈퇴(재인증 → 새 authorization_code를 백엔드에 전달 →
        // 백엔드가 Apple revoke 호출, D9)는 백엔드 `/auth/login/apple`이
        // 먼저 필요한 W3b에서 구현한다(D14). Apple 로그인 자체가 아직
        // 없으므로 현재는 이 분기에 도달할 수 없다 — 자리만 만들어 둔다.
        await _showUnsupportedProviderDialog(context, 'Apple');
        break;
      default:
        // provider를 못 받았거나(네트워크 실패 등) 인식할 수 없는 값이면
        // 예전 방식대로 판단한다: 카카오 세션이 있으면 카카오 흐름, 없으면
        // 이메일 흐름. 탈퇴를 막는 것보다 안전하다(App Store 5.1.1(v)).
        await _showLegacyDetectedDeleteDialog(context);
    }
  }

  /// provider를 알 수 없을 때(네트워크 실패, 알 수 없는 값)의 폴백. W3a
  /// 이전 방식 그대로 카카오 세션 존재 여부로 판단한다.
  static Future<void> _showLegacyDetectedDeleteDialog(
    BuildContext context,
  ) async {
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
        await AuthService.logout(context, provider: 'kakao');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog(context, '계정 탈퇴 중 오류가 발생했습니다: $e');
    }
  }

  static Future<void> _showEmailDeleteDialog(BuildContext context) async {
    final cupertino = isCupertino(context);
    final password = cupertino
        ? await showCupertinoDialog<String>(
            context: context,
            builder: (_) => const _PasswordPromptBody(cupertino: true),
          )
        : await showDialog<String>(
            context: context,
            builder: (_) => const _PasswordPromptBody(cupertino: false),
          );
    if (password == null || password.isEmpty) return;
    try {
      await MyProfileService().deleteAccountWithPassword(password);
      if (context.mounted) {
        await AuthService.logout(context, provider: 'email');
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

  static Future<void> _showUnsupportedProviderDialog(
    BuildContext context,
    String providerLabel,
  ) async {
    _showErrorDialog(context, '$providerLabel 계정은 아직 탈퇴를 지원하지 않습니다.');
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

/// 이메일 탈퇴용 비밀번호 입력 다이얼로그.
///
/// 확인을 누르면 입력한 비밀번호 문자열을, 취소하면 null을 반환한다.
/// design system의 `showAppTextInputAlert`(app_dialogs.dart, W2 소유)는
/// `obscureText`를 지원하지 않아 이 파일에서 직접 구현했다(§6 W3a 3항 "또는
/// 동등한 iOS 알럿").
class _PasswordPromptBody extends StatefulWidget {
  const _PasswordPromptBody({required this.cupertino});

  final bool cupertino;

  @override
  State<_PasswordPromptBody> createState() => _PasswordPromptBodyState();
}

class _PasswordPromptBodyState extends State<_PasswordPromptBody> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cupertino) {
      return CupertinoAlertDialog(
        title: const Text('계정 탈퇴'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text('계정 탈퇴를 위해 비밀번호를 입력해주세요.'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _controller,
                obscureText: true,
                autofocus: true,
                placeholder: '비밀번호',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('유지하기'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('탈퇴하기'),
          ),
        ],
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final canSubmit = _controller.text.trim().isNotEmpty;
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
                controller: _controller,
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
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF111111),
                      side: const BorderSide(color: Colors.transparent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('유지하기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSubmit
                        ? () => Navigator.of(context).pop(_controller.text)
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
                    child: const Text('탈퇴하기'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
