import 'package:flutter/material.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/my/ui/widgets/my_info_widgets.dart';
import 'package:after30/utils/responsive.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key});

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  String? _nickname;
  String? _email;
  String? _phoneNumber;
  String? _gender;
  String? _imageUrl;
  bool _marketingConsent = false;
  bool _isKakaoLoggedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _nickname = args['nickname'] as String?;
      _imageUrl = args['imageUrl'] as String?;
      _marketingConsent = (args['allowMarketing'] as bool?) ?? false;
    }
    _loadKakaoAccount();
  }

  Future<void> _loadKakaoAccount() async {
    try {
      final user = await UserApi.instance.me();
      final account = user.kakaoAccount;
      if (!mounted) return;
      setState(() {
        _nickname = _nickname ?? account?.profile?.nickname ?? '사용자';
        _imageUrl = _imageUrl ?? account?.profile?.profileImageUrl;
        _email = account?.email;
        _isKakaoLoggedIn = true;
      });
      await _loadBackendProfile(preserveKakaoState: true);
    } catch (_) {
      await _loadBackendProfile();
    }
  }

  Future<void> _loadBackendProfile({bool preserveKakaoState = false}) async {
    try {
      final profile = await MyProfileService().getMyProfile();
      if (!mounted) return;
      setState(() {
        _nickname = profile.name ?? _nickname ?? '사용자';
        _email = profile.email ?? _email;
        _phoneNumber = profile.phoneNumber;
        _gender = profile.gender;
        _marketingConsent = profile.allowMarketing ?? _marketingConsent;
        _imageUrl = _imageUrl ?? profile.profileImageUrl;
        if (profile.provider != null) {
          _isKakaoLoggedIn = profile.provider!.toLowerCase().contains('kakao');
        }
      });
    } catch (_) {
      if (!mounted || preserveKakaoState) return;
      setState(() {
        _isKakaoLoggedIn = false;
      });
    }
  }

  void _applyProfile(MyProfile profile) {
    setState(() {
      _nickname = profile.name ?? _nickname ?? '사용자';
      _email = profile.email ?? _email;
      _phoneNumber = profile.phoneNumber;
      _gender = profile.gender;
      _marketingConsent = profile.allowMarketing ?? _marketingConsent;
      _imageUrl = profile.profileImageUrl ?? _imageUrl;
      if (profile.provider != null) {
        _isKakaoLoggedIn = profile.provider!.toLowerCase().contains('kakao');
      }
    });
  }

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

  String _formatSso(bool isKakaoLoggedIn) =>
      isKakaoLoggedIn ? '카카오톡' : '이메일';

  Future<void> _openEditPage() async {
    final result = await Navigator.of(context).pushNamed(
      '/my-info-edit',
      arguments: {
        'name': _nickname,
        'phoneNumber': _phoneNumber,
        'email': _email,
        'gender': _gender,
        'isKakaoLoggedIn': _isKakaoLoggedIn,
      },
    );
    if (!mounted) return;
    if (result is MyProfile) {
      _applyProfile(result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원정보가 수정되었습니다.')),
      );
    }
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
                MyInfoHeader(
                  actionLabel: '수정하기',
                  actionFilled: false,
                  onBack: () => Navigator.of(context).pop(),
                  onAction: _openEditPage,
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 16)),
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
                      MyInfoReadRow(
                        label: '연동된 SSO',
                        value: _formatSso(_isKakaoLoggedIn),
                      ),
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
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 4),
    );
  }
}
