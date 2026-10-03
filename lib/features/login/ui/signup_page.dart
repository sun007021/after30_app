import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/core/storage/token_store.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/auth_form_scaffold.dart';
import 'package:after30/utils/responsive.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedGender; // '남' or '여'
  bool _obscurePw = true;
  bool _obscurePwConfirm = true;
  bool _submitting = false;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

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

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');
  static const int _minPasswordLength = 8;

  bool get _isFormValid {
    final nameOk = _nameController.text.trim().isNotEmpty;
    final genderOk = _selectedGender != null;
    final email = _emailController.text.trim();
    final emailOk = _emailRegex.hasMatch(email);
    final pw = _passwordController.text;
    final pw2 = _confirmPasswordController.text;
    final pwOk = pw.length >= _minPasswordLength && pw == pw2;
    return nameOk && genderOk && emailOk && pwOk;
  }

  bool get _passwordTooShort {
    final pw = _passwordController.text;
    return pw.isNotEmpty && pw.length < _minPasswordLength;
  }

  bool get _passwordMismatch {
    final pw = _passwordController.text;
    final pw2 = _confirmPasswordController.text;
    return pw2.isNotEmpty && pw != pw2;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
    _confirmPasswordController.addListener(_onChanged);
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertino(context);
    return _buildMaterial(context);
  }

  // iOS: 이름 → 성별(세그먼트) → 이메일 → 비밀번호 → 확인 순서. 이름/이메일/
  // 비밀번호는 자동완성 그룹으로 묶어 iOS가 강력한 비밀번호를 제안하게 한다.
  Widget _buildCupertino(BuildContext context) {
    return AuthFormScaffold(
      title: '회원가입',
      subtitle: '식후 30분과 함께 복약 습관을 시작해요',
      cta: AppButton(
        label: '등록',
        loading: _submitting,
        onPressed: _isFormValid && !_submitting ? _onSubmit : null,
      ),
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameController,
                label: '이름',
                placeholder: '이름을 입력하세요',
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              const Text(
                '성별',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: AppSegmentedControl<String>(
                  options: const [
                    AppSegmentedOption(value: '남', label: '남'),
                    AppSegmentedOption(value: '여', label: '여'),
                  ],
                  value: _selectedGender,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: '이메일',
                placeholder: '이메일을 입력하세요',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: '비밀번호',
                placeholder: '비밀번호를 8자 이상 입력하세요',
                obscureText: true,
                showObscureToggle: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                errorText: _passwordTooShort ? '비밀번호는 최소 8자 이상이어야 합니다' : null,
                onSubmitted: (_) => _confirmFocus.requestFocus(),
              ),
              if (!_passwordTooShort)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '8자 이상으로 입력해주세요',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
                  ),
                ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmPasswordController,
                focusNode: _confirmFocus,
                label: '비밀번호 재입력',
                placeholder: '비밀번호를 다시 입력해주세요',
                obscureText: true,
                showObscureToggle: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                errorText: _passwordMismatch ? '비밀번호가 일치하지 않습니다' : null,
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
                        '이름',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/infoicon.svg',
                          child: TextField(
                            controller: _nameController,
                            decoration: _innerDecoration(context, '이름을 입력하세요'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      _labeled(
                        context,
                        '성별',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/infoicon.svg',
                          child: _genderField(context),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      _labeled(
                        context,
                        '이메일',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/emailicon.svg',
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _innerDecoration(context, '이메일을 입력하세요'),
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
                            onPressed: () {
                              setState(() {
                                _obscurePw = !_obscurePw;
                              });
                            },
                          ),
                          child: TextField(
                            controller: _passwordController,
                            decoration: _innerDecoration(
                              context,
                              '비밀번호를 8자 이상 입력하세요',
                            ),
                            obscureText: _obscurePw,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 16),
                      ),
                      _labeled(
                        context,
                        '비밀번호 재입력',
                        _iconField(
                          context,
                          asset: 'assets/images/signupicon/pwicon.svg',
                          trailing: IconButton(
                            iconSize: _trailingIconSize(context),
                            icon: Icon(
                              _obscurePwConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePwConfirm = !_obscurePwConfirm;
                              });
                            },
                          ),
                          child: TextField(
                            controller: _confirmPasswordController,
                            decoration: _innerDecoration(
                              context,
                              '비밀번호를 다시 입력해주세요',
                            ),
                            obscureText: _obscurePwConfirm,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),
                      if (_passwordTooShort)
                        Padding(
                          padding: EdgeInsets.only(
                            top: Responsive.responsiveValue(context, 6),
                          ),
                          child: Text(
                            '비밀번호는 최소 8자 이상이어야 합니다',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                12,
                              ),
                            ),
                          ),
                        )
                      else if (_passwordMismatch)
                        Padding(
                          padding: EdgeInsets.only(
                            top: Responsive.responsiveValue(context, 6),
                          ),
                          child: Text(
                            '비밀번호가 일치하지 않습니다',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                12,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        height: Responsive.responsiveHeight(context, 32),
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
                                    '등록',
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
      padding: Responsive.responsivePaddingLTRB(context, 24, 5, 24, 50),
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
                // 제목 오른쪽 로고
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
                  '회원가입',
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

  Widget _genderField(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: Colors.white,
        value: _selectedGender,
        isExpanded: true,
        hint: Text(
          '성별을 선택하세요',
          style: TextStyle(
            fontSize: _placeholderFontSize(context),
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
          ),
        ),
        items: const [
          DropdownMenuItem(value: '남', child: Text('남')),
          DropdownMenuItem(value: '여', child: Text('여')),
        ],
        onChanged: (v) {
          setState(() {
            _selectedGender = v;
          });
        },
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
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _fieldHeight(context)),
      child: Container(
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
      ),
    );
  }

  InputDecoration _innerDecoration(BuildContext context, String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        color: const Color(0xFF9CA3AF),
        fontSize: _placeholderFontSize(context),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(
        vertical: Responsive.responsiveValue(context, 10),
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
    final name = _nameController.text.trim();
    final gender = _selectedGender ?? '';
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
    });
    try {
      await BackendAuthService().registerWithEmail(
        name: name,
        gender: gender,
        email: email,
        password: password,
      );
      // 가입 후에는 토큰/세션을 정리하고 로그인 화면으로 유도
      await TokenStore.clear();
      if (!mounted) return;
      // 가입 성공: 키체인에 새 자격 증명 저장 제안을 띄운다.
      if (cupertino) TextInput.finishAutofillContext();
      AppToast.show(
        context,
        '회원가입이 완료되었습니다. 로그인 화면으로 이동합니다.',
        type: AppToastType.success,
      );
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/email-login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      final msg = _onlyMessage(e);
      AppToast.show(context, msg, type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _onlyMessage(Object error) {
    final s = error.toString();
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
