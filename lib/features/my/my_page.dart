import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/my/settings_store.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/common/page_title.dart';

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
      // 무시: 로그인 상태가 아니거나 권한 오류 시 기본 값 사용
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
                  nickname: _nickname ?? '사용자님의 정보',
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
                    items: const ['앱 정보', '개인정보 처리방침', '로그아웃', '계정탈퇴', '고객센터'],
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
