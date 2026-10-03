import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/my/ui/widgets/my_info_widgets.dart';
import 'package:after30/utils/responsive.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key, this.profileService, this.userService});

  /// 테스트에서 주입. 기본값은 실제 백엔드 서비스.
  final MyProfileService? profileService;
  final UserService? userService;

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  String? _nickname;
  String? _email;
  String? _phoneNumber;
  String? _gender;
  bool _marketingConsent = false;
  String? _provider;

  // 프로필 로딩. 요청 순번으로 늦게 온 이전 응답이 새 응답을 덮지 않게 한다.
  int _requestSeq = 0;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _argsApplied = false;

  // 번호 등록 시트 중복 오픈 방지.
  bool _registeringPhone = false;

  MyProfileService get _profileService => widget.profileService ?? MyProfileService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    _argsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _nickname = args['nickname'] as String?;
      _marketingConsent = (args['allowMarketing'] as bool?) ?? false;
    }
    _loadProfile();
  }

  /// 백엔드 `/users/me`로 읽는다(카카오 전용 SDK 호출에 의존하지 않는다).
  Future<void> _loadProfile() async {
    final seq = ++_requestSeq;
    try {
      final profile = await _profileService.getMyProfile();
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _applyProfileFields(profile);
        _loaded = true;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      // 이미 불러온 값이 있으면 일시적 실패로 화면을 바꾸지 않는다.
      if (!_loaded) setState(() => _loadFailed = true);
    }
  }

  void _applyProfileFields(MyProfile profile) {
    _nickname = profile.name ?? _nickname ?? '사용자';
    _email = profile.email ?? _email;
    _phoneNumber = profile.phoneNumber;
    _gender = profile.gender;
    _marketingConsent = profile.allowMarketing ?? _marketingConsent;
    _provider = profile.provider ?? _provider;
  }

  void _applyProfile(MyProfile profile) {
    setState(() {
      _applyProfileFields(profile);
      _loaded = true;
      _loadFailed = false;
    });
  }

  bool get _hasPhone => _phoneNumber != null && _phoneNumber!.trim().isNotEmpty;

  String _formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '-';
    if (phone.contains('-')) return phone;
    return PhoneUtil.toApiPhoneQuery(phone);
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.trim().isEmpty) return '-';
    switch (gender.trim().toUpperCase()) {
      case 'M':
      case 'MALE':
      case '남':
        return '남';
      case 'F':
      case 'FEMALE':
      case '여':
        return '여';
      default:
        return gender;
    }
  }

  String _formatMarketingConsent(bool consent) => consent ? '동의' : '미동의';

  /// 제공자를 알면 백엔드 표시명을, 모르면 기존 기본값(이메일)을 쓴다.
  String get _ssoLabel =>
      _provider != null ? MyProfile.providerDisplayNameFor(_provider) : '이메일';

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).pushNamed(
      '/my-info-edit',
      arguments: {
        'name': _nickname,
        'phoneNumber': _phoneNumber,
        'email': _email,
        'gender': _gender,
        'isKakaoLoggedIn': (_provider ?? '').toLowerCase().contains('kakao'),
        'provider': _provider,
      },
    );
    if (!mounted) return;
    if (result is MyProfile) {
      _applyProfile(result);
      AppToast.show(context, '회원정보가 수정되었습니다.', type: AppToastType.success);
    }
  }

  /// 번호가 비어 있는 행에서 등록 시트를 연다. 성공하면 프로필을 다시 읽는다.
  Future<void> _registerPhone() async {
    if (_registeringPhone) return;
    _registeringPhone = true;
    try {
      final phone = await showPhoneRegisterSheet(
        context: context,
        profileService: _profileService,
        userService: widget.userService,
      );
      if (!mounted || phone == null) return;
      // 재조회가 실패해도 "미등록"이 남지 않게 저장된 번호를 먼저 반영한다.
      setState(() => _phoneNumber = phone);
      await _loadProfile();
      if (!mounted) return;
      AppToast.show(context, '전화번호가 등록되었습니다.', type: AppToastType.success);
    } finally {
      _registeringPhone = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return Scaffold(
      backgroundColor: cupertino
          ? AppColors.groupedBackground
          : const Color(0xFFEBF0FF),
      appBar: cupertino
          ? AppNavBar(
              title: '내 정보',
              actions: [
                MyInfoNavAction(label: '수정', onPressed: _openEditPage),
              ],
            )
          : null,
      body: AppShellTabActivationListener(
        tabIndex: AppShellTab.my,
        // 다른 탭(가족)에서 전화번호를 등록하고 돌아오면 "미등록"을 지운다.
        onActivated: _loadProfile,
        child: cupertino ? _buildCupertinoBody() : _buildMaterialBody(context),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 4),
    );
  }

  Widget _buildCupertinoBody() {
    return SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_loadFailed) ...[
            AppGroupedSection(
              children: [
                AppListTile(
                  title: '내 정보를 불러오지 못했어요',
                  subtitle: '탭하여 다시 시도',
                  onTap: _loadProfile,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          AppGroupedSection(
            header: '기본 정보',
            children: [
              MyInfoReadRow(label: '성명', value: _nickname ?? '-'),
              if (_loaded && !_hasPhone)
                AppListTile(
                  title: '전화번호',
                  trailing: const Text(
                    '미등록',
                    style: TextStyle(fontSize: 17, color: AppColors.primary),
                  ),
                  showChevron: false,
                  onTap: _registerPhone,
                )
              else
                MyInfoReadRow(label: '전화번호', value: _formatPhone(_phoneNumber)),
              MyInfoReadRow(label: '성별', value: _formatGender(_gender)),
              MyInfoReadRow(label: '이메일 주소', value: _email ?? '-'),
              MyInfoReadRow(label: '연동된 SSO', value: _ssoLabel),
            ],
          ),
          const SizedBox(height: 24),
          AppGroupedSection(
            header: '기타 정보',
            children: [
              MyInfoReadRow(
                label: '광고 정보 수신 동의',
                value: _formatMarketingConsent(_marketingConsent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialBody(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: Responsive.responsivePaddingLTRB(context, 20, 36, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyInfoHeader(
                actionLabel: '수정하기',
                actionFilled: false,
                onBack: () => Navigator.of(context).pop(),
                onAction: _openEditPage,
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 16)),
              if (_loadFailed) ...[
                InkWell(
                  onTap: _loadProfile,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '내 정보를 불러오지 못했어요. 탭하여 다시 시도',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 12),
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 8)),
              ],
              MyInfoSectionCard(
                title: '기본 정보',
                child: Column(
                  children: [
                    MyInfoReadRow(label: '성명', value: _nickname ?? '-'),
                    SizedBox(
                      height: Responsive.responsiveHeight(context, 14),
                    ),
                    MyInfoReadRow(
                      label: '전화번호',
                      value: _formatPhone(_phoneNumber),
                    ),
                    SizedBox(
                      height: Responsive.responsiveHeight(context, 14),
                    ),
                    MyInfoReadRow(
                      label: '성별',
                      value: _formatGender(_gender),
                    ),
                    SizedBox(
                      height: Responsive.responsiveHeight(context, 14),
                    ),
                    MyInfoReadRow(label: '이메일 주소', value: _email ?? '-'),
                    SizedBox(
                      height: Responsive.responsiveHeight(context, 14),
                    ),
                    MyInfoReadRow(label: '연동된 SSO', value: _ssoLabel),
                  ],
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 15)),
              MyInfoSectionCard(
                title: '기타 정보',
                child: MyInfoReadRow(
                  label: '광고 정보 수신 동의',
                  value: _formatMarketingConsent(_marketingConsent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
