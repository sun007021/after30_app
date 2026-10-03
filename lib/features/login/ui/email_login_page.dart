import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/auth/auth_provider_client.dart';
import 'package:after30/core/auth/session_bootstrapper.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/auth_form_scaffold.dart';
import 'package:after30/utils/responsive.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);
  BorderRadius _fieldRadius(BuildContext context) => BorderRadius.all(
    Radius.circular(Responsive.responsiveValue(context, 12)),
  );
  double _fieldIconSize(BuildContext context) =>
      Responsive.responsiveIconSize(context, 12);
  double _placeholderFontSize(BuildContext context) =>
      Responsive.responsiveFontSize(context, 14);
  double _trailingIconSize(BuildContext context) =>
      Responsive.responsiveIconSize(context, 16);
  double _fieldHeight(BuildContext context) =>
      Responsive.responsiveHeight(context, 46);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePw = true;
  bool _submitting = false;
  final FocusNode _passwordFocus = FocusNode();
  // iOS 인라인 오류(Android는 기존처럼 SnackBar)
  String? _errorText;

  bool get _isFormValid {
    final email = _emailController.text.trim();
    final emailOk = email.contains('@') && email.contains('.');
    final pw = _passwordController.text;
    return emailOk && pw.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
  }

  void _onChanged() {
    setState(() {
      _errorText = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  // iOS: 토큰 스타일 폼. 자동완성 그룹으로 묶어 iCloud 키체인이 자격 증명을
  // 제안하게 하고, CTA는 키보드 위에 고정한다.
  Widget _buildCupertino(BuildContext context) {
    return AuthFormScaffold(
      title: '로그인',
      subtitle: '이메일과 비밀번호를 입력해주세요',
      cta: AppButton(
        label: '로그인',
        loading: _submitting,
        onPressed: _isFormValid && !_submitting ? _onSubmit : null,
      ),
      children: [
        // 기본값(commit)이면 화면을 닫을 때마다 iOS가 키체인 저장을 제안한다.
        // 실패했거나 제출하지 않은 값이 저장되지 않게 성공 시에만 직접 commit한다.
        AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Column(
            children: [
              AppTextField(
                controller: _emailController,
                label: '이메일',
                placeholder: '이메일 주소',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: '비밀번호',
                placeholder: '비밀번호',
                obscureText: true,
                showObscureToggle: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                errorText: _errorText,
                onSubmitted: (_) {
                  if (_isFormValid && !_submitting) _onSubmit();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) {
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
                  padding: Responsive.responsivePaddingLTRB(
                    context,
                    36,
                    24,
                    36,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _labeled(
                        context,
                        '이메일',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/emailicon.svg',
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _innerDecoration(context, '이메일 주소'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      _labeled(
                        context,
                        '비밀번호',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/pwicon.svg',
                          trailing: IconButton(
                            iconSize: _trailingIconSize(context),
                            icon: Icon(
                              _obscurePw
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(() {
                              _obscurePw = !_obscurePw;
                            }),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            decoration: _innerDecoration(context, '비밀번호'),
                            obscureText: _obscurePw,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 39),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: Responsive.responsiveHeight(context, 30),
                          width: Responsive.responsiveValue(context, 120),
                          child: ElevatedButton(
                            onPressed: _isFormValid && !_submitting
                                ? _onSubmit
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
                            child: _submitting
                                ? SizedBox(
                                    width: Responsive.responsiveValue(
                                      context,
                                      16,
                                    ),
                                    height: Responsive.responsiveValue(
                                      context,
                                      16,
                                    ),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '로그인',
                                    style: TextStyle(
                                      fontSize: Responsive.responsiveFontSize(
                                        context,
                                        14,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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
      padding: Responsive.responsivePaddingLTRB(context, 24, 5, 24, 59),
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
                  icon: SvgPicture.asset(
                    'assets/images/signupicon/backicon.svg',
                    width: Responsive.responsiveValue(context, 18),
                    height: Responsive.responsiveValue(context, 16),
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
                  '식후 30분',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.responsiveFontSize(context, 30),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: Responsive.responsiveValue(context, 10)),
                SvgPicture.asset(
                  'assets/images/signupicon/namelogo.svg',
                  width: Responsive.responsiveIconSize(context, 24),
                  height: Responsive.responsiveIconSize(context, 24),
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
                  '로그인',
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

  Widget _iconField(
    BuildContext context, {
    required String asset,
    required Widget child,
    Widget? trailing,
    double? width,
  }) {
    return Container(
      height: _fieldHeight(context),
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: _fieldRadius(context),
        border: Border.all(color: const Color(0xFF111111), width: 1),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.responsiveValue(context, 12),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            asset,
            width: _fieldIconSize(context),
            height: _fieldIconSize(context),
          ),
          SizedBox(width: Responsive.responsiveValue(context, 12)),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  InputDecoration _innerDecoration(BuildContext context, String hint) {
    return InputDecoration(
      isDense: true,
      hintText: ' ',
      // hint를 전달하되 style은 아래에서 override
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(
        vertical: Responsive.responsiveValue(context, 10),
      ),
    ).copyWith(
      hintText: hint,
      hintStyle: TextStyle(
        color: const Color(0xFF9CA3AF),
        fontSize: _placeholderFontSize(context),
      ),
    );
  }

  Widget _labeled(BuildContext context, String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
            ),
          ),
        ),
        SizedBox(height: Responsive.responsiveHeight(context, 8)),
        SizedBox(width: double.infinity, child: field),
      ],
    );
  }

  Future<void> _onSubmit() async {
    // 더블탭/키보드 완료 중복 제출 방지: await 이전에 동기적으로 막는다.
    if (_submitting) return;
    final cupertino = isCupertino(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      // 토큰 저장 → 사용자 ID 통합(구 카카오ID/이메일 폴백 → 백엔드 ID) →
      // 알람 네임스페이스 마이그레이션 → 재스케줄 → FCM 동기화 → 셸
      // 진입까지는 SessionBootstrapper가 공통으로 처리한다(plan §6 W3a
      // 1항).
      await SessionBootstrapper.completeLogin(
        context,
        EmailAuthProviderClient(email: email, password: password),
      );
      // 로그인 성공: iCloud 키체인에 자격 증명 저장 제안을 띄운다.
      if (cupertino) TextInput.finishAutofillContext();
    } catch (e) {
      if (!mounted) return;
      final friendly = _friendlyLoginErrorMessage(e);
      if (cupertino) {
        setState(() => _errorText = friendly);
      } else {
        AppToast.show(context, friendly);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _friendlyLoginErrorMessage(Object error) {
    // BackendAuthService.loginWithEmail 은 DioException 을
    // 'Exception: 이메일 로그인 실패 ($status): $body' 형태의 문자열로 감싸 던진다.
    // 응답을 받지 못한 경우(status == null) 는 연결 실패·타임아웃 등 네트워크 오류다.
    final s = error.toString();
    final statusMatch = RegExp(r'실패\s*\((\d{3}|null)\)').firstMatch(s);
    final statusToken = statusMatch?.group(1);

    if (statusToken == 'null') {
      return '네트워크 연결을 확인해주세요.';
    }

    final status = int.tryParse(statusToken ?? '');
    if (status == 401 || s.contains('일치하지 않습니다')) {
      return '이메일 또는 비밀번호가 일치하지 않습니다.';
    }
    if (status == 422) {
      return '이메일 형식을 확인해주세요.';
    }
    if (status != null && status >= 500) {
      return '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
  }
}
