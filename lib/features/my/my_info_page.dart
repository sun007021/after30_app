import 'package:flutter/material.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/common/page_title.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/utils/responsive.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key});

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  String? _nickname;
  String? _email;
  String? _imageUrl;
  bool _marketingConsent = false;
  bool _isKakaoLoggedIn = false;

  Future<void> _openExternalLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
    } catch (_) {
      // 카카오 미로그인(=이메일 로그인 등)인 경우 백엔드 프로필 조회
      await _loadBackendProfile();
    }
  }

  Future<void> _loadBackendProfile() async {
    try {
      final profile = await MyProfileService().getMyProfile();
      if (!mounted) return;
      setState(() {
        _nickname = _nickname ?? profile.name ?? '사용자';
        _email = profile.email ?? _email;
        _marketingConsent = profile.allowMarketing ?? _marketingConsent;
        _imageUrl = _imageUrl ?? profile.profileImageUrl;
        _isKakaoLoggedIn = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isKakaoLoggedIn = false;
      });
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
                Padding(
                  padding: EdgeInsets.only(
                    top: Responsive.responsiveHeight(context, 18),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: Responsive.responsiveIconSize(context, 22),
                        ),
                      ),
                      SizedBox(width: Responsive.responsiveWidth(context, 8)),
                      const PageTitle(
                        title: '내 정보 조회',
                        margin: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 8)),

                // 기본 정보 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('기본 정보'),
                      Divider(height: Responsive.responsiveHeight(context, 24)),
                      _InfoRow(label: '성명', value: _nickname ?? '-'),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      _InfoRow(label: '이메일 주소', value: _email ?? '-'),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      if (_isKakaoLoggedIn)
                        const _InfoRow(label: '연동된 SSO', value: '카카오톡'),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.responsiveHeight(context, 20)),

                // 기타 정보 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('기타 정보'),
                      Divider(height: Responsive.responsiveHeight(context, 24)),
                      SizedBox(height: Responsive.responsiveHeight(context, 4)),
                      _InfoRow(
                        label: '개인정보 수집 및 이용 동의',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: Responsive.responsiveIconSize(context, 24),
                        ),
                        onTap: () => _openExternalLink(
                          'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link',
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 12),
                      ),
                      _InfoRow(
                        label: '서비스 이용약관',
                        trailing: Icon(
                          Icons.chevron_right,
                          size: Responsive.responsiveIconSize(context, 24),
                        ),
                        onTap: () => _openExternalLink(
                          'https://www.notion.so/30-2b2ac07ca4e98040a729c7433c26a896?source=copy_link',
                        ),
                      ),
                    ],
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: Responsive.responsivePadding(context, 16, 14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 16),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _InfoRow({required this.label, this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 14),
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(width: Responsive.responsiveWidth(context, 1)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    child:
                        trailing ??
                        Text(
                          value ?? '-',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(
                              context,
                              14,
                            ),
                            color: Colors.black87,
                          ),
                        ),
                  )
                : (trailing ??
                      Text(
                        value ?? '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 14),
                          color: Colors.black87,
                        ),
                      )),
          ),
        ),
      ],
    );
  }
}
