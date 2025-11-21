import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/features/login/data/backend_auth_service.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';
import 'package:after30/features/home/ui/home.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  static const Color _primaryBlue = Color(0xFF235DFF);
  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const double _fieldIconSize = 12;
  static const double _placeholderFontSize = 14;
  static const double _trailingIconSize = 16;
  static const double _fieldHeight = 46;
  static const double _fieldWidth = 290;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePw = true;
  bool _submitting = false;

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
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _labeled(
                        '이메일',
                        _iconField(
                          asset: 'assets/images/signupicon/emailicon.svg',
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _innerDecoration('이메일 주소'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        '비밀번호',
                        _iconField(
                          asset: 'assets/images/signupicon/pwicon.svg',
                          trailing: IconButton(
                            iconSize: _trailingIconSize,
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
                            decoration: _innerDecoration('비밀번호'),
                            obscureText: _obscurePw,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),
                      const SizedBox(height: 39),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: 30,
                          width: 120,
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
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '로그인',
                                    style: TextStyle(
                                      fontSize: 14,
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
      padding: const EdgeInsets.fromLTRB(24, 5, 24, 59),
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
                padding: const EdgeInsets.only(left: 12),
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
                  '식후 30분',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                SvgPicture.asset(
                  'assets/images/signupicon/namelogo.svg',
                  width: 24,
                  height: 24,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: const [
                Text(
                  '로그인',
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

  Widget _iconField({
    required String asset,
    required Widget child,
    Widget? trailing,
    double? width,
  }) {
    return Container(
      height: _fieldHeight,
      width: width ?? _fieldWidth,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: _fieldRadius,
        border: Border.all(color: const Color(0xFF111111), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SvgPicture.asset(
            asset,
            width: _fieldIconSize,
            height: _fieldIconSize,
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  InputDecoration _innerDecoration(String hint) {
    return const InputDecoration(
      isDense: true,
      hintText: ' ',
      // hint를 전달하되 style은 아래에서 override
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: 10),
    ).copyWith(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: _placeholderFontSize,
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: _fieldWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: SizedBox(width: _fieldWidth, child: field),
        ),
      ],
    );
  }

  Future<void> _onSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
    });
    try {
      await BackendAuthService().loginWithEmail(
        email: email,
        password: password,
      );
      await UserStore.setCurrentUserId(email);
      AlarmService.setCurrentUserId(email);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final friendly = _friendlyLoginErrorMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _friendlyLoginErrorMessage(Object error) {
    final s = error.toString();
    if (s.contains('(401)') || s.contains('401') || s.contains('일치하지 않습니다')) {
      return '이메일 또는 비밀번호가 일치하지 않습니다.';
    }
    return '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
  }
}
