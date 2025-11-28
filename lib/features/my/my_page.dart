import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/my/settings_store.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:dio/dio.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _allowPush = true;
  bool _allowDevice = true;
  String? _nickname;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadKakaoProfile();
  }

  Future<void> _loadSettings() async {
    final push = await MySettingsStore.getAllowPushNotifications();
    final device = await MySettingsStore.getAllowDeviceNotifications();
    if (!mounted) return;
    setState(() {
      _allowPush = push;
      _allowDevice = device;
    });
  }

  Future<void> _loadKakaoProfile() async {
    try {
      final user = await UserApi.instance.me();
      final nickname = user.kakaoAccount?.profile?.nickname;
      final imageUrl = user.kakaoAccount?.profile?.profileImageUrl;
      if (!mounted) return;
      setState(() {
        _nickname = nickname;
        _profileImageUrl = imageUrl;
      });
    } catch (_) {
      // 카카오 세션이 없으면 백엔드 프로필 조회 (이메일 로그인 등)
      await _loadBackendProfile();
    }
  }

  Future<void> _loadBackendProfile() async {
    try {
      final profile = await MyProfileService().getMyProfile();
      if (!mounted) return;
      setState(() {
        _nickname = profile.name ?? _nickname ?? '사용자';
        _profileImageUrl = profile.profileImageUrl ?? _profileImageUrl;
      });
    } catch (_) {
      // 프로필 조회 실패 시 기존 기본값 유지
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: <String, dynamic>{
          'android.provider.extra.APP_PACKAGE': 'com.example.after30',
        },
      );
      await intent.launch();
    } else if (Platform.isIOS) {
      final uri = Uri.parse('app-settings:');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageTitle(
                  title: '마이페이지',
                  margin: EdgeInsets.only(left: 16, top: 20),
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  nickname: _nickname ?? '사용자',
                  imageUrl: _profileImageUrl,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      '/my-info',
                      arguments: {
                        'nickname': _nickname,
                        'imageUrl': _profileImageUrl,
                        'allowMarketing': _allowPush,
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: const Text(
                    '알람설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                _CardContainer(
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: '푸시 알림 허용',
                        value: _allowPush,
                        onChanged: (v) async {
                          setState(() => _allowPush = v);
                          await MySettingsStore.setAllowPushNotifications(v);
                        },
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        title: '디바이스 알람 허용',
                        value: _allowDevice,
                        onChanged: (v) async {
                          setState(() => _allowDevice = v);
                          await MySettingsStore.setAllowDeviceNotifications(v);
                          if (v) {
                            await _openSystemNotificationSettings();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _LinkList(
                    items: const [
                      '앱 정보',
                      '개인정보 처리방침',
                      '로그아웃',
                      '계정탈퇴',
                      '사용자 의견 보내기',
                    ],
                    onTapIndex: (i) async {
                      if (i == 2) {
                        // 로그아웃: 토큰 삭제 후 로그인으로 이동
                        await _logout(context);
                      } else if (i == 1) {
                        final uri = Uri.parse(
                          'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      } else if (i == 3) {
                        await _handleDeleteAccount(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 4),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String nickname;
  final String? imageUrl;
  final VoidCallback onTap;
  const _ProfileTile({
    required this.nickname,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: imageUrl != null
                    ? NetworkImage(imageUrl!)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$nickname님의 정보',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    );
  }
}

Future<void> _logout(BuildContext context) async {
  await AuthService.logout(context);
}

Future<void> _handleDeleteAccount(BuildContext context) async {
  // 현재 카카오 세션이 있는지 확인
  bool hasKakaoSession = false;
  try {
    await UserApi.instance.accessTokenInfo();
    hasKakaoSession = true;
  } catch (_) {
    hasKakaoSession = false;
  }

  if (hasKakaoSession) {
    // 카카오 재인증 안내 후 재로그인 절차 진행
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('탈퇴 실패'),
          content: Text('계정 탈퇴 중 오류가 발생했습니다: $e'),
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
  } else {
    // 이메일 로그인: 비밀번호 재입력
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('탈퇴 실패'),
          content: Text('계정 탈퇴 중 오류가 발생했습니다: $e'),
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
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF235DFF),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}

class _LinkList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onTapIndex;
  const _LinkList({required this.items, required this.onTapIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          InkWell(
            onTap: () => onTapIndex(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                items[i],
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
