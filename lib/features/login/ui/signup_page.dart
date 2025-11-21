import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  static const Color _primaryBlue = Color(0xFF235DFF);
  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const double _fieldIconSize = 12;
  static const double _placeholderFontSize = 14;
  static const double _trailingIconSize = 16;
  static const double _fieldHeight = 46;
  static const double _fieldWidth = 290;

  bool get _isFormValid {
    final nameOk = _nameController.text.trim().isNotEmpty;
    final genderOk = _selectedGender != null;
    final email = _emailController.text.trim();
    final emailOk = email.contains('@') && email.contains('.');
    final pw = _passwordController.text;
    final pw2 = _confirmPasswordController.text;
    final pwOk = pw.isNotEmpty && pw == pw2;
    return nameOk && genderOk && emailOk && pwOk;
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
                        '이름',
                        _iconField(
                          asset: 'assets/images/signupicon/infoicon.svg',
                          child: TextField(
                            controller: _nameController,
                            decoration: _innerDecoration('이름을 입력하세요'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        '성별',
                        _iconField(
                          asset: 'assets/images/signupicon/infoicon.svg',
                          child: _genderField(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        '이메일',
                        _iconField(
                          asset: 'assets/images/signupicon/emailicon.svg',
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _innerDecoration('이메일을 입력하세요'),
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
                            onPressed: () {
                              setState(() {
                                _obscurePw = !_obscurePw;
                              });
                            },
                          ),
                          child: TextField(
                            controller: _passwordController,
                            decoration: _innerDecoration('비밀번호를 8자 이상 입력하세요'),
                            obscureText: _obscurePw,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        '비밀번호 재입력',
                        _iconField(
                          asset: 'assets/images/signupicon/pwicon.svg',
                          trailing: IconButton(
                            iconSize: _trailingIconSize,
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
                            decoration: _innerDecoration('비밀번호를 다시 입력해주세요'),
                            obscureText: _obscurePwConfirm,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: 30,
                          width: 120,
                          child: ElevatedButton(
                            onPressed: _isFormValid ? _onSubmit : null,
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
                              '등록',
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
                  '식후 30분',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                // 제목 오른쪽 로고
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
              children: [
                const Text(
                  '회원가입',
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

  Widget _genderField() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        dropdownColor: Colors.white,
        value: _selectedGender,
        isExpanded: true,
        hint: const Text(
          '성별을 선택하세요',
          style: TextStyle(
            fontSize: _placeholderFontSize,
            color: Color(0xFF9CA3AF),
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
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: _placeholderFontSize,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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

  void _onSubmit() {
    // 실제 회원가입 API 연동 전까지는 단순 안내만 표시
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회원가입 데이터 전송 준비 중입니다')));
  }
}
