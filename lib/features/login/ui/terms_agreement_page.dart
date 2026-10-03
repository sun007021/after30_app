import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/auth_form_scaffold.dart';
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
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
      opened = false;
    }
    if (!opened && mounted) {
      AppToast.show(context, '약관 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.', type: AppToastType.error);
    }
  }

  static const _personalInfoUrl =
      'https://www.notion.so/pysun/2876b9ce737380ccb3bcc6a07f68d682?source=copy_link';
  static const _serviceTermsUrl =
      'https://www.notion.so/30-2b2ac07ca4e98040a729c7433c26a896?source=copy_link';

  // iOS: 약관 상세는 시트로 연다. 전문은 시트의 "전문 보기"에서 외부 링크로
  // 열고, 필수 약관 동의 여부만 CTA를 제어한다(선택 약관은 현재 없음).
  Future<void> _showTermSheet(String title, String url) {
    return showAppSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
            ),
            const SizedBox(height: 8),
            const Text(
              '서비스 이용을 위해 반드시 동의가 필요한 항목입니다. 자세한 내용은 전문에서 확인할 수 있어요.',
              style: TextStyle(fontSize: 15, color: AppColors.secondaryLabel, height: 1.4),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: '전문 보기',
              variant: AppButtonVariant.tinted,
              onPressed: () => _openExternalLink(url),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: '닫기',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cupertinoTermTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String url,
  }) {
    // AppCheckmark에는 시맨틱이 없어 VoiceOver가 동의 여부를 읽도록 행에 붙인다.
    return Semantics(
      checked: value,
      child: AppListTile(
        title: title,
        leadingWidth: 44,
        leading: AppCheckmark(checked: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: () => _showTermSheet(title, url),
          child: const Icon(CupertinoIcons.chevron_forward, size: 18, color: AppColors.secondaryLabel),
        ),
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    return AuthFormScaffold(
      title: '약관 동의',
      subtitle: '필수 약관에 동의해 주세요',
      backgroundColor: AppColors.groupedBackground,
      cta: AppButton(
        label: '동의하기',
        onPressed: _allRequiredAgreed
            ? () => Navigator.of(context).pushNamed('/signup')
            : null,
      ),
      children: [
        AppGroupedSection(
          children: [
            Semantics(
              checked: _allRequiredAgreed,
              child: AppListTile(
                title: '전체 동의',
                leadingWidth: 44,
                leading: AppCheckmark(
                  checked: _allRequiredAgreed,
                  onChanged: _toggleAll,
                ),
                onTap: () => _toggleAll(!_allRequiredAgreed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppGroupedSection(
          children: [
            _cupertinoTermTile(
              title: '(필수) 개인정보 수집 및 이용 동의',
              value: _agreePersonalInfo,
              onChanged: (v) => setState(() => _agreePersonalInfo = v),
              url: _personalInfoUrl,
            ),
            _cupertinoTermTile(
              title: '(필수) 서비스 이용약관',
              value: _agreeServiceTerms,
              onChanged: (v) => setState(() => _agreeServiceTerms = v),
              url: _serviceTermsUrl,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertino(context);
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
