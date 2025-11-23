import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAgreementPage extends StatefulWidget {
  const TermsAgreementPage({super.key});

  @override
  State<TermsAgreementPage> createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);
  static const double _horizontalPadding = 28;

  bool _agreePersonalInfo = false; // (필수) 개인정보 수집 및 이용 동의
  bool _agreeServiceTerms = false; // (필수) 서비스 이용약관
  bool _agreeRealNameId = false; // (필수) 실명 인증된 아이디로 가입
  bool _agreeLocationBased = false; // (필수) 위치기반 서비스 이용약관
  bool _agreeMarketing = false; // (선택) 광고 정보 수신 동의

  bool get _allRequiredAgreed =>
      _agreePersonalInfo &&
      _agreeServiceTerms &&
      _agreeRealNameId &&
      _agreeLocationBased;

  bool get _allAgreed => _allRequiredAgreed && _agreeMarketing;

  void _toggleAll(bool value) {
    setState(() {
      _agreePersonalInfo = value;
      _agreeServiceTerms = value;
      _agreeRealNameId = value;
      _agreeLocationBased = value;
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
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    300,
                    _horizontalPadding,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSelectAllTile(),
                      const SizedBox(height: 1),
                      const Divider(color: Color(0xFF111111)),
                      _buildTermRow(
                        title: '(필수)개인정보 수집 및 이용 동의',
                        value: _agreePersonalInfo,
                        onChanged: (v) =>
                            setState(() => _agreePersonalInfo = v),
                        linkUrl:
                            'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link',
                      ),
                      _buildTermRow(
                        title: '(필수)서비스 이용약관',
                        value: _agreeServiceTerms,
                        onChanged: (v) =>
                            setState(() => _agreeServiceTerms = v),
                        linkUrl:
                            'https://www.notion.so/30-2b2ac07ca4e98040a729c7433c26a896?source=copy_link',
                      ),
                      const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        5,
        _horizontalPadding,
        50,
      ),
      decoration: const BoxDecoration(color: _primaryBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: SvgPicture.asset(
                  'assets/images/signupicon/backicon.svg',
                  width: 18,
                  height: 16,
                ),
                padding: EdgeInsets.only(left: 12),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 12),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '약관동의',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Text(
                  '필수 및 선택약관에 동의해 주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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

  Widget _buildSelectAllTile() {
    final bool allCurrentlyAgreed = _allAgreed;
    return GestureDetector(
      onTap: () => _toggleAll(!allCurrentlyAgreed),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // 전체 동의 상태 아이콘
            allCurrentlyAgreed
                ? SvgPicture.asset(
                    'assets/images/term/allagree.svg',
                    width: 24,
                    height: 24,
                  )
                : SvgPicture.asset(
                    'assets/images/term/notall.svg',
                    width: 24,
                    height: 24,
                  ),
            const SizedBox(width: 8),
            const Text(
              '전체 약관동의',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? linkUrl,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            value
                ? Image.asset(
                    'assets/images/term/agree.png',
                    width: 24,
                    height: 24,
                  )
                : SvgPicture.asset(
                    'assets/images/term/disagree.svg',
                    width: 24,
                    height: 24,
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            InkWell(
              onTap: linkUrl != null ? () => _openExternalLink(linkUrl) : null,
              child: const Icon(Icons.chevron_right, color: Color(0xFF111111)),
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
        height: 30,
        width: 120,
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
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: const Text(
            '동의하기',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
