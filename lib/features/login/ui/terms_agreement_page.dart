import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:after30/utils/responsive.dart';

class TermsAgreementPage extends StatefulWidget {
  const TermsAgreementPage({super.key});

  @override
  State<TermsAgreementPage> createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);
  double _horizontalPadding(BuildContext context) =>
      Responsive.responsiveValue(context, 28);

  bool _agreePersonalInfo = false; // (필수) 개인정보 수집 및 이용 동의
  bool _agreeServiceTerms = false; // (필수) 서비스 이용약관
  bool _agreeMarketing = false; // (선택) 광고 정보 수신 동의

  bool get _allRequiredAgreed => _agreePersonalInfo && _agreeServiceTerms;

  bool get _allAgreed => _allRequiredAgreed && _agreeMarketing;

  void _toggleAll(bool value) {
    setState(() {
      _agreePersonalInfo = value;
      _agreeServiceTerms = value;
      _agreeMarketing = value;
    });
  }

  Future<void> _openExternalLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    _horizontalPadding(context),
                    Responsive.responsiveValue(context, 300),
                    _horizontalPadding(context),
                    Responsive.responsiveValue(context, 24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSelectAllTile(context),
                      SizedBox(height: Responsive.responsiveHeight(context, 1)),
                      Divider(color: const Color(0xFF111111)),
                      _buildTermRow(
                        context,
                        title: '(필수)개인정보 수집 및 이용 동의',
                        value: _agreePersonalInfo,
                        onChanged: (v) =>
                            setState(() => _agreePersonalInfo = v),
                        linkUrl:
                            'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link',
                      ),
                      _buildTermRow(
                        context,
                        title: '(필수)서비스 이용약관',
                        value: _agreeServiceTerms,
                        onChanged: (v) =>
                            setState(() => _agreeServiceTerms = v),
                        linkUrl:
                            'https://www.notion.so/30-2b2ac07ca4e98040a729c7433c26a896?source=copy_link',
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 24),
                      ),
                      _buildAgreeButton(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        Responsive.responsiveValue(context, 5),
        _horizontalPadding(context),
        Responsive.responsiveValue(context, 50),
      ),
      decoration: const BoxDecoration(color: _primaryBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.zero,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Transform.translate(
                    offset: const Offset(-3, 0),
                    child: SvgPicture.asset(
                      'assets/images/signupicon/backicon.svg',
                      width: Responsive.responsiveValue(context, 18),
                      height: Responsive.responsiveValue(context, 16),
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 28)),
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.responsiveValue(context, 12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '약관동의',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.responsiveFontSize(context, 30),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 9)),
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.responsiveValue(context, 12),
            ),
            child: Row(
              children: [
                Text(
                  '필수 및 선택약관에 동의해 주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.responsiveFontSize(context, 15),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllTile(BuildContext context) {
    final bool allCurrentlyAgreed = _allAgreed;
    return GestureDetector(
      onTap: () => _toggleAll(!allCurrentlyAgreed),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: Responsive.responsiveValue(context, 6),
        ),
        child: Row(
          children: [
            // 전체 동의 상태 아이콘
            allCurrentlyAgreed
                ? SvgPicture.asset(
                    'assets/images/term/allagree.svg',
                    width: Responsive.responsiveIconSize(context, 24),
                    height: Responsive.responsiveIconSize(context, 24),
                  )
                : SvgPicture.asset(
                    'assets/images/term/notall.svg',
                    width: Responsive.responsiveIconSize(context, 24),
                    height: Responsive.responsiveIconSize(context, 24),
                  ),
            SizedBox(width: Responsive.responsiveWidth(context, 8)),
            Text(
              '전체 약관동의',
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? linkUrl,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: Responsive.responsiveValue(context, 8),
        ),
        child: Row(
          children: [
            value
                ? Image.asset(
                    'assets/images/term/agree.png',
                    width: Responsive.responsiveIconSize(context, 24),
                    height: Responsive.responsiveIconSize(context, 24),
                  )
                : SvgPicture.asset(
                    'assets/images/term/disagree.svg',
                    width: Responsive.responsiveIconSize(context, 24),
                    height: Responsive.responsiveIconSize(context, 24),
                  ),
            SizedBox(width: Responsive.responsiveWidth(context, 8)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 12),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            InkWell(
              onTap: linkUrl != null ? () => _openExternalLink(linkUrl) : null,
              child: Icon(
                Icons.chevron_right,
                color: const Color(0xFF111111),
                size: Responsive.responsiveIconSize(context, 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _checkIcon 제거: 아이콘은 제공된 에셋을 사용

  Widget _buildAgreeButton(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        height: Responsive.responsiveHeight(context, 30),
        width: Responsive.responsiveValue(context, 120),
        child: ElevatedButton(
          onPressed: _allRequiredAgreed
              ? () {
                  Navigator.of(context).pushNamed('/signup');
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD3DEFF),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                Responsive.responsiveValue(context, 5),
              ),
            ),
          ),
          child: Text(
            '동의하기',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 14),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
