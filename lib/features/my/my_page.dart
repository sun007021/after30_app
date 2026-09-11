import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/my/settings_store.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/ui/widgets/profile_tile.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';
import 'package:after30/features/my/ui/widgets/switch_row.dart';
import 'package:after30/features/my/ui/widgets/link_list.dart';
import 'package:after30/features/my/ui/widgets/delete_account_dialog.dart';
import 'package:after30/utils/responsive.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/services/notifications/fcm_service.dart';

// 개인정보 처리방침 문서 링크
const String _privacyPolicyUrl =
    'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link';
// 사용자 의견 보내기(Tally 설문 폼) 링크
const String _feedbackFormUrl = 'https://tally.so/r/zx9v5R';

// 앱 정보 다이얼로그 표시값. pubspec.yaml의 version 필드가 바뀌면 함께 갱신할 것.
const String _appDisplayName = '식후 30분';
const String _appVersion = '0.0.1+3';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with WidgetsBindingObserver {
  static const MethodChannel _nativeChannel = MethodChannel('after30/native');
  bool _allowPush = true;
  bool _allowDevice = true;
  String? _nickname;
  String? _profileImageUrl;
  bool _allowMarketing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _loadKakaoProfile();
    _refreshDeviceAlarmState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDeviceAlarmState();
    }
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

  Future<bool> _isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      final allowed = await _nativeChannel.invokeMethod<bool>(
        'isExactAlarmAllowed',
      );
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final ignored = await _nativeChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return ignored ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<bool>('openExactAlarmSettings');
    } catch (_) {}
  }

  Future<void> _openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeChannel.invokeMethod<bool>(
        'openBatteryOptimizationSettings',
      );
    } catch (_) {}
  }

  Future<bool> _refreshDeviceAlarmState() async {
    final exactAllowed = await _isExactAlarmAllowed();
    final batteryIgnored = await _isIgnoringBatteryOptimizations();
    return exactAllowed && batteryIgnored;
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
      await _loadBackendProfile();
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
        _allowMarketing = profile.allowMarketing ?? _allowMarketing;
      });
    } catch (_) {
      // 프로필 조회 실패 시 기존 기본값 유지
    }
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);
    final launched =
        canLaunch && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _showAppInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(_appDisplayName),
        content: const Text('버전 $_appVersion'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: Responsive.responsivePaddingLTRB(context, 20, 36, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.responsiveValue(context, 8),
                  ),
                  child: Text(
                    '마이페이지',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 18),
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 16)),
                ProfileTile(
                  nickname: _nickname ?? '사용자',
                  imageUrl: _profileImageUrl,
                  onTap: () async {
                    await Navigator.of(context).pushNamed(
                      '/my-info',
                      arguments: {
                        'nickname': _nickname,
                        'imageUrl': _profileImageUrl,
                        'allowMarketing': _allowMarketing,
                      },
                    );
                    if (!mounted) return;
                    await _loadBackendProfile();
                  },
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 24)),
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.responsiveValue(context, 4),
                  ),
                  child: Text(
                    '알람설정',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 13),
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
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
                          await FcmService.setPushEnabled(v);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchRow(
                        title: '디바이스 알람 허용',
                        value: _allowDevice,
                        onChanged: (v) async {
                          setState(() => _allowDevice = v);
                          await MySettingsStore.setAllowDeviceNotifications(v);

                          if (!v) {
                            await AlarmService().cancelAllActiveAlarmSchedules();
                            return;
                          }

                          if (Platform.isAndroid) {
                            await _openExactAlarmSettings();
                            await _openBatteryOptimizationSettings();
                          }

                          await AlarmService().rescheduleAllActiveFromStorage();

                          final ready = await _refreshDeviceAlarmState();
                          if (!mounted) return;
                          if (ready) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('디바이스 알람 준비가 완료되었습니다.'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '토글은 켜졌지만 기기 설정이 아직 미완료입니다. 정확 알람/배터리 최적화 해제를 확인해주세요.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 36)),
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.responsiveValue(context, 4),
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
                      if (i == 0) {
                        await _showAppInfoDialog();
                      } else if (i == 1) {
                        await _openExternalLink(_privacyPolicyUrl);
                      } else if (i == 2) {
                        final confirmed = await DoubleCheckDialog.show(
                          context: context,
                          title: '로그아웃 하시겠습니까?',
                          message: '로그아웃 시 복약 알람이 안와요.',
                          cancelLabel: '취소',
                          confirmLabel: '로그아웃',
                        );
                        if (!confirmed) return;
                        await AuthService.logout(context);
                      } else if (i == 3) {
                        await DeleteAccountDialog.show(context);
                      } else if (i == 4) {
                        await _openExternalLink(_feedbackFormUrl);
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
