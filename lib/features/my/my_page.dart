import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/my/device_alarm_gateway.dart';
import 'package:after30/features/my/settings_store.dart';
import 'package:after30/features/login/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

// 앱 정보 다이얼로그 표시값. 버전은 PackageInfo에서 읽는다.
const String _appDisplayName = '식후 30분';

/// 카카오 SDK에서 프로필 이미지 URL만 읽어 온다(백엔드에 이미지가 없을 때만
/// 쓰는 대체 경로). 세션이 없거나 실패하면 null.
Future<String?> _kakaoProfileImageUrl() async {
  try {
    final user = await UserApi.instance.me();
    return user.kakaoAccount?.profile?.profileImageUrl;
  } catch (_) {
    return null;
  }
}

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    this.profileService,
    this.deviceAlarm = const MyDeviceAlarmGateway(),
    this.loadPackageInfo = PackageInfo.fromPlatform,
    this.kakaoProfileImageLoader = _kakaoProfileImageUrl,
    this.logout,
    this.deleteAccount,
  });

  /// 테스트에서 주입. 기본값은 실제 백엔드 서비스.
  final MyProfileService? profileService;
  final MyDeviceAlarmGateway deviceAlarm;
  final Future<PackageInfo> Function() loadPackageInfo;
  final Future<String?> Function() kakaoProfileImageLoader;

  /// 테스트에서 주입. 기본값은 [AuthService.logout].
  final Future<void> Function(BuildContext context)? logout;

  /// 테스트에서 주입. 기본값은 [DeleteAccountDialog.show].
  final Future<void> Function(BuildContext context)? deleteAccount;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with WidgetsBindingObserver {
  bool _allowPush = true;
  bool _allowDevice = true;
  String? _nickname;
  String? _profileImageUrl;
  bool _allowMarketing = false;

  // 프로필 로딩 상태. 요청 순번으로 늦게 온 이전 응답이 새 응답을 덮지 않게 한다.
  int _profileRequestSeq = 0;
  bool _profileLoaded = false;
  bool _profileFailed = false;
  bool _phoneMissing = false;

  // iOS 기기 알람 권한 상태(Android에서는 쓰지 않는다).
  MyDeviceAlarmStatus? _deviceStatus;
  bool _deviceStateRequested = false;

  // 로그아웃/탈퇴 중복 실행 방지.
  bool _accountActionBusy = false;

  MyProfileService get _profileService => widget.profileService ?? MyProfileService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 테마(플랫폼)를 읽어야 하므로 initState가 아니라 여기서 첫 갱신을 한다.
    if (!_deviceStateRequested) {
      _deviceStateRequested = true;
      _refreshDeviceAlarmState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 셸 안에서는 셸이 포그라운드 복귀를 활성 탭에만 알리므로
    // (_onTabActivated) 여기서 또 부르면 중복이고 다른 탭에 있어도 불린다.
    if (state == AppLifecycleState.resumed && AppShell.maybeOf(context) == null) {
      // 설정 앱에서 권한을 바꾸고 돌아온 경우 상태 행을 갱신한다.
      _refreshDeviceAlarmState();
    }
  }

  /// 마이 탭이 다시 활성화될 때(다른 탭에서 전화번호를 등록하고 돌아온 경우
  /// 등) 프로필과 알람 권한 상태를 다시 불러온다.
  void _onTabActivated() {
    _loadProfile();
    _refreshDeviceAlarmState();
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

  /// Android: 정확한 알람/배터리 최적화 준비 여부(기존 판정). iOS: 알림 권한
  /// 상태를 새로 읽어 상태 행에 반영하고, 알림이 허용돼 있으면 준비 완료로 본다.
  Future<bool> _refreshDeviceAlarmState() async {
    if (!mounted) return false;
    if (isCupertino(context)) {
      final status = await widget.deviceAlarm.loadStatus();
      if (!mounted) return status.alarmsReady;
      setState(() => _deviceStatus = status);
      return status.alarmsReady;
    }
    return widget.deviceAlarm.isAndroidReady();
  }

  /// 백엔드 `/users/me`를 읽어 프로필을 채운다. 이메일 가입자도 같은 경로를
  /// 쓴다. 이미지가 없고 카카오 가입자일 때만 카카오 SDK로 이미지를 대체한다.
  Future<void> _loadProfile() async {
    final seq = ++_profileRequestSeq;
    try {
      final profile = await _profileService.getMyProfile();
      if (!mounted || seq != _profileRequestSeq) return;
      setState(() {
        _nickname = profile.name ?? _nickname ?? '사용자';
        _profileImageUrl = profile.profileImageUrl ?? _profileImageUrl;
        _allowMarketing = profile.allowMarketing ?? _allowMarketing;
        _phoneMissing = !profile.hasPhoneNumber;
        _profileLoaded = true;
        _profileFailed = false;
      });
      if (profile.profileImageUrl == null &&
          (profile.provider ?? '').toLowerCase().contains('kakao')) {
        final kakaoImage = await widget.kakaoProfileImageLoader();
        if (!mounted || seq != _profileRequestSeq || kakaoImage == null) return;
        setState(() => _profileImageUrl = _profileImageUrl ?? kakaoImage);
      }
    } catch (_) {
      if (!mounted || seq != _profileRequestSeq) return;
      // 이미 한 번 불러온 값이 있으면 일시적 실패로 화면을 바꾸지 않는다.
      if (!_profileLoaded) setState(() => _profileFailed = true);
    }
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);
    final launched =
        canLaunch && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!mounted) return;
      AppToast.show(
        context,
        '링크를 열 수 없습니다. 잠시 후 다시 시도해주세요.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _showAppInfoDialog() async {
    String? version;
    String? build;
    try {
      final info = await widget.loadPackageInfo();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}
    if (!mounted) return;

    if (isCupertino(context)) {
      final message = version == null
          ? '버전 정보를 확인할 수 없어요.'
          : (build == null || build.isEmpty)
          ? '버전 $version'
          : '버전 $version ($build)';
      await showAppAlert(
        context: context,
        title: _appDisplayName,
        message: message,
      );
      return;
    }

    final text = version == null
        ? '버전 정보를 확인할 수 없어요.'
        : (build == null || build.isEmpty)
        ? '버전 $version'
        : '버전 $version+$build';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(_appDisplayName),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMyInfo() async {
    await Navigator.of(context).pushNamed(
      '/my-info',
      arguments: {
        'nickname': _nickname,
        'imageUrl': _profileImageUrl,
        'allowMarketing': _allowMarketing,
      },
    );
    if (!mounted) return;
    await _loadProfile();
  }

  Future<void> _onPushChanged(bool v) async {
    setState(() => _allowPush = v);
    await MySettingsStore.setAllowPushNotifications(v);
    await FcmService.setPushEnabled(v);
  }

  Future<void> _onDeviceAlarmChanged(bool v) async {
    setState(() => _allowDevice = v);
    await MySettingsStore.setAllowDeviceNotifications(v);

    if (!v) {
      await AlarmService().cancelAllActiveAlarmSchedules();
      return;
    }

    // Android 전용 네이티브 설정 화면 열기(iOS에서는 어댑터가 아무것도 하지 않는다).
    await widget.deviceAlarm.openExactAlarmSettings();
    await widget.deviceAlarm.openBatteryOptimizationSettings();

    await AlarmService().rescheduleAllActiveFromStorage();

    if (!mounted) return;
    final ready = await _refreshDeviceAlarmState();
    if (!mounted) return;
    if (ready) {
      AppToast.show(context, '디바이스 알람 준비가 완료되었습니다.');
    } else if (isCupertino(context)) {
      AppToast.show(
        context,
        '토글은 켜졌지만 알림 권한이 꺼져 있어요. 설정에서 알림을 허용해주세요.',
        type: AppToastType.error,
      );
    } else {
      AppToast.show(
        context,
        '토글은 켜졌지만 기기 설정이 아직 미완료입니다. 정확 알람/배터리 최적화 해제를 확인해주세요.',
      );
    }
  }

  Future<void> _logout() async {
    if (_accountActionBusy) return;
    _accountActionBusy = true;
    try {
      final bool confirmed;
      if (isCupertino(context)) {
        final result = await showAppActionSheet<bool>(
          context: context,
          title: '로그아웃 하시겠습니까?',
          message: '로그아웃 시 복약 알람이 안와요.',
          actions: const [
            AppActionSheetAction(label: '로그아웃', value: true, destructive: true),
          ],
          cancelLabel: '취소',
        );
        confirmed = result == true;
      } else {
        confirmed = await DoubleCheckDialog.show(
          context: context,
          title: '로그아웃 하시겠습니까?',
          message: '로그아웃 시 복약 알람이 안와요.',
          cancelLabel: '취소',
          confirmLabel: '로그아웃',
        );
      }
      if (!confirmed) return;
      // base와 동일: 확인 뒤에는 mounted 여부와 무관하게 로그아웃을 진행한다
      // (AuthService.logout이 내부에서 context.mounted를 확인한다).
      // ignore: use_build_context_synchronously
      await (widget.logout ?? AuthService.logout)(context);
    } finally {
      _accountActionBusy = false;
    }
  }

  Future<void> _deleteAccount() async {
    if (_accountActionBusy) return;
    _accountActionBusy = true;
    try {
      await (widget.deleteAccount ?? DeleteAccountDialog.show)(context);
    } finally {
      _accountActionBusy = false;
    }
  }

  Future<void> _onInfoLinkTap(int i) async {
    if (i == 0) {
      await _showAppInfoDialog();
    } else if (i == 1) {
      await _openExternalLink(_privacyPolicyUrl);
    } else if (i == 2) {
      await _openExternalLink(_feedbackFormUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return Scaffold(
      backgroundColor: cupertino
          ? AppColors.groupedBackground
          : const Color(0xFFEBF0FF),
      body: AppShellTabActivationListener(
        tabIndex: AppShellTab.my,
        onActivated: _onTabActivated,
        child: cupertino ? _buildCupertinoBody(context) : _buildMaterialBody(context),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 4),
    );
  }

  // ---------------------------------------------------------------------
  // iOS: inset grouped 설정 목록
  // ---------------------------------------------------------------------

  Widget _buildCupertinoBody(BuildContext context) {
    final status = _deviceStatus;
    return CustomScrollView(
      slivers: [
        const AppSliverNavBar(
          title: '마이페이지',
          showBackButton: false,
          backgroundColor: AppColors.groupedBackground,
          showBorder: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ProfileTile(
                nickname: _nickname ?? '사용자',
                imageUrl: _profileImageUrl,
                loadFailed: _profileFailed,
                onRetry: _loadProfile,
                subtitle: _phoneMissing ? '전화번호 미등록' : null,
                onTap: _openMyInfo,
              ),
              const SizedBox(height: 24),
              AppGroupedSection(
                header: '알람 설정',
                // 위 두 스위치는 앱 설정이고, 아래 행들은 OS 권한 상태라는 점을 알린다.
                footer: status != null ? '아래 항목은 기기 설정의 권한 상태예요.' : null,
                children: [
                  SwitchRow(
                    title: '푸시 알림 허용',
                    value: _allowPush,
                    onChanged: _onPushChanged,
                  ),
                  SwitchRow(
                    title: '디바이스 알람 허용',
                    value: _allowDevice,
                    onChanged: _onDeviceAlarmChanged,
                  ),
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: 16),
                AppGroupedSection(children: _deviceStatusRows(status)),
              ],
              const SizedBox(height: 24),
              LinkList(
                header: '정보',
                items: const ['앱 정보', '개인정보 처리방침', '사용자 의견 보내기'],
                onTapIndex: _onInfoLinkTap,
              ),
              const SizedBox(height: 24),
              LinkList(
                header: '계정',
                items: const ['로그아웃', '계정탈퇴'],
                destructiveIndexes: const {1},
                showChevron: false,
                onTapIndex: (i) => i == 0 ? _logout() : _deleteAccount(),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// "알림 권한 / 시간 민감 알림 / (AlarmKit) / 설정에서 허용하기" 행들.
  List<Widget> _deviceStatusRows(MyDeviceAlarmStatus status) {
    return [
      _statusRow('알림 권한', _notificationLabel(status.notification)),
      _statusRow(
        '시간 민감 알림',
        status.notificationAllowed
            ? (status.timeSensitiveAllowed ? '허용됨' : '꺼짐')
            : (status.notification == NotificationAuthorizationStatus.notDetermined
                  ? '미결정'
                  : '꺼짐'),
      ),
      if (status.alarmKit != AlarmKitAuthorizationStatus.notSupported)
        _statusRow('알람(AlarmKit)', _alarmKitLabel(status.alarmKit)),
      if (status.notification == NotificationAuthorizationStatus.notDetermined)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '처음 약을 등록할 때 알림 권한을 요청해요.',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
          ),
        ),
      if (_shouldOfferSettings(status))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: AppButton(
            label: '설정에서 허용하기',
            variant: AppButtonVariant.tinted,
            size: AppButtonSize.medium,
            onPressed: () => widget.deviceAlarm.openAppSettings(),
          ),
        ),
    ];
  }

  /// 설정 앱으로 가는 버튼을 보여줄지. AlarmKit이 허용이면 알람 자체는 울리지만,
  /// 푸시(FCM)와 가족 알림은 알림 권한이 필요하므로 "푸시 알림 허용"이 켜져 있고
  /// 알림이 거부된 경우에도 보여준다(미결정은 첫 약 등록 때 요청하므로 제외).
  bool _shouldOfferSettings(MyDeviceAlarmStatus status) {
    if (status.needsSettings) return true;
    return _allowPush &&
        status.alarmKitAuthorized &&
        status.notification == NotificationAuthorizationStatus.denied;
  }

  Widget _statusRow(String title, String value) {
    return AppListTile(
      title: title,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 17,
          color: value == '허용됨' ? AppColors.label : AppColors.secondaryLabel,
        ),
      ),
    );
  }

  String _notificationLabel(NotificationAuthorizationStatus s) {
    switch (s) {
      case NotificationAuthorizationStatus.authorized:
      case NotificationAuthorizationStatus.ephemeral:
        return '허용됨';
      case NotificationAuthorizationStatus.provisional:
        // 알림 센터에만 조용히 쌓이고 소리/배너는 나오지 않는다.
        return '조용히 전달';
      case NotificationAuthorizationStatus.denied:
        return '꺼짐';
      case NotificationAuthorizationStatus.notDetermined:
        return '미결정';
    }
  }

  String _alarmKitLabel(AlarmKitAuthorizationStatus s) {
    switch (s) {
      case AlarmKitAuthorizationStatus.authorized:
        return '허용됨';
      case AlarmKitAuthorizationStatus.denied:
        return '꺼짐';
      case AlarmKitAuthorizationStatus.notDetermined:
      case AlarmKitAuthorizationStatus.notSupported:
        return '미결정';
    }
  }

  // ---------------------------------------------------------------------
  // Android: 기존 외형 그대로
  // ---------------------------------------------------------------------

  Widget _buildMaterialBody(BuildContext context) {
    return SafeArea(
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
                loadFailed: _profileFailed,
                onRetry: _loadProfile,
                onTap: _openMyInfo,
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
                      onChanged: _onPushChanged,
                    ),
                    const Divider(height: 1),
                    SwitchRow(
                      title: '디바이스 알람 허용',
                      value: _allowDevice,
                      onChanged: _onDeviceAlarmChanged,
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
                      await _logout();
                    } else if (i == 3) {
                      await _deleteAccount();
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
    );
  }
}
