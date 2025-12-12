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
import 'package:after30/features/my/ui/widgets/profile_tile.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';
import 'package:after30/features/my/ui/widgets/switch_row.dart';
import 'package:after30/features/my/ui/widgets/link_list.dart';
import 'package:after30/features/my/ui/widgets/delete_account_dialog.dart';
import 'package:after30/utils/responsive.dart';

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
            padding: Responsive.responsivePaddingLTRB(context, 20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageTitle(
                  title: '마이페이지',
                  margin: Responsive.responsiveMarginLTRB(
                    context,
                    16,
                    20,
                    0,
                    0,
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 8)),
                ProfileTile(
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
                SizedBox(height: Responsive.responsiveHeight(context, 24)),
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.responsiveValue(context, 16),
                  ),
                  child: Text(
                    '알람설정',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 12)),
                CardContainer(
                  child: Column(
                    children: [
                      SwitchRow(
                        title: '푸시 알림 허용',
                        value: _allowPush,
                        onChanged: (v) async {
                          setState(() => _allowPush = v);
                          await MySettingsStore.setAllowPushNotifications(v);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchRow(
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
                SizedBox(height: Responsive.responsiveHeight(context, 36)),
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.responsiveValue(context, 16),
                  ),
                  child: LinkList(
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
                        await AuthService.logout(context);
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
                        await DeleteAccountDialog.show(context);
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
