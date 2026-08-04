import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/features/my/ui/widgets/my_info_widgets.dart';
import 'package:after30/utils/responsive.dart';

class MyInfoEditPage extends StatefulWidget {
  const MyInfoEditPage({super.key});

  @override
  State<MyInfoEditPage> createState() => _MyInfoEditPageState();
}

class _MyInfoEditPageState extends State<MyInfoEditPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ssoController = TextEditingController();
  final _userService = UserService();

  String? _gender;
  String _initialPhone = '';
  bool _isKakaoLoggedIn = false;
  bool _isSaving = false;
  bool _isCheckingPhone = false;
  bool _isPhoneVerified = false;
  String? _phoneCheckMessage;
  Color _phoneCheckColor = const Color(0xFF235DFF);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _nameController.text = (args['name'] as String?) ?? '';
      _initialPhone = _formatPhone(args['phoneNumber'] as String?);
      _phoneController.text = _initialPhone;
      _emailController.text = (args['email'] as String?) ?? '';
      _gender = _normalizeGender(args['gender'] as String?);
      _isKakaoLoggedIn = (args['isKakaoLoggedIn'] as bool?) ?? false;
      _ssoController.text = _isKakaoLoggedIn ? '카카오톡' : '이메일';
      _isPhoneVerified = _initialPhone.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ssoController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final current = _normalizedPhone(_phoneController.text);
    final isSameAsInitial =
        current.isNotEmpty && current == _normalizedPhone(_initialPhone);

    if (isSameAsInitial) {
      if (!_isPhoneVerified || _phoneCheckMessage != null) {
        setState(() {
          _isPhoneVerified = true;
          _phoneCheckMessage = null;
        });
      }
      return;
    }

    if (_isPhoneVerified || _phoneCheckMessage != null) {
      setState(() {
        _isPhoneVerified = false;
        _phoneCheckMessage = null;
      });
    }
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    if (phone.contains('-')) return phone;
    return PhoneUtil.toApiPhoneQuery(phone);
  }

  String _normalizedPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    return PhoneUtil.toApiPhoneQuery(trimmed);
  }

  String? _normalizeGender(String? gender) {
    if (gender == null || gender.trim().isEmpty) return null;
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

  String _saveErrorMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) return '이미 등록된 전화번호입니다.';
    if (status == 422) return '전화번호 형식이 올바르지 않습니다.';
    return '정보 수정에 실패했습니다. 다시 시도해주세요.';
  }

  Future<void> _checkPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력해주세요.')),
      );
      return;
    }
    if (!PhoneUtil.isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 전화번호 형식이 아닙니다.')),
      );
      return;
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneCheckMessage = null;
    });

    try {
      final normalized = _normalizedPhone(phone);
      final isDuplicate = await _userService.isPhoneDuplicate(phone);
      final isOwnNumber = normalized == _normalizedPhone(_initialPhone);

      if (!mounted) return;

      if (isDuplicate && !isOwnNumber) {
        setState(() {
          _isPhoneVerified = false;
          _phoneCheckMessage = '이미 사용 중인 번호입니다.';
          _phoneCheckColor = const Color(0xFFE53935);
        });
      } else {
        setState(() {
          _isPhoneVerified = true;
          _phoneCheckMessage = '사용 가능한 번호입니다.';
          _phoneCheckColor = const Color(0xFF235DFF);
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      setState(() {
        _isPhoneVerified = false;
        _phoneCheckMessage = status == 422
            ? '전화번호 형식이 올바르지 않습니다.'
            : '번호 확인에 실패했습니다. 다시 시도해주세요.';
        _phoneCheckColor = const Color(0xFFE53935);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPhoneVerified = false;
        _phoneCheckMessage = '번호 확인에 실패했습니다. 다시 시도해주세요.';
        _phoneCheckColor = const Color(0xFFE53935);
      });
    } finally {
      if (mounted) setState(() => _isCheckingPhone = false);
    }
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성명을 입력해주세요.')),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력해주세요.')),
      );
      return;
    }
    if (!PhoneUtil.isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 전화번호 형식이 아닙니다.')),
      );
      return;
    }
    if (!_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호 확인을 먼저 진행해주세요.')),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await MyProfileService().updateMyProfile(
        name: name,
        gender: _gender!,
        phoneNumber: PhoneUtil.toApiPhoneQuery(phone),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saveErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정보 수정에 실패했습니다. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                  actionLabel: '수정완료',
                  actionFilled: true,
                  onBack: () => Navigator.of(context).pop(),
                  onAction: _isSaving ? () {} : _onSave,
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 16)),
                MyInfoSectionCard(
                  title: '기본 정보',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyInfoFieldLabel(label: '성명'),
                      SizedBox(height: Responsive.responsiveHeight(context, 6)),
                      MyInfoTextField(controller: _nameController),
                      SizedBox(height: Responsive.responsiveHeight(context, 10)),
                      const MyInfoFieldLabel(label: '전화번호'),
                      SizedBox(height: Responsive.responsiveHeight(context, 6)),
                      _MyInfoEditPhoneField(
                        controller: _phoneController,
                        isChecking: _isCheckingPhone,
                        onCheck: _checkPhone,
                      ),
                      if (_phoneCheckMessage != null) ...[
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 6),
                        ),
                        Text(
                          _phoneCheckMessage!,
                          style: TextStyle(
                            fontSize: Responsive.responsiveFontSize(context, 11),
                            fontWeight: FontWeight.w400,
                            color: _phoneCheckColor,
                          ),
                        ),
                      ],
                      SizedBox(height: Responsive.responsiveHeight(context, 10)),
                      const MyInfoFieldLabel(label: '성별'),
                      SizedBox(height: Responsive.responsiveHeight(context, 6)),
                      MyInfoGenderSelector(
                        selectedGender: _gender,
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      SizedBox(height: Responsive.responsiveHeight(context, 10)),
                      const MyInfoFieldLabel(label: '이메일 주소'),
                      SizedBox(height: Responsive.responsiveHeight(context, 6)),
                      MyInfoTextField(
                        controller: _emailController,
                        readOnly: true,
                      ),
                      SizedBox(height: Responsive.responsiveHeight(context, 10)),
                      const MyInfoFieldLabel(label: '연동된 SSO'),
                      SizedBox(height: Responsive.responsiveHeight(context, 6)),
                      MyInfoTextField(
                        controller: _ssoController,
                        readOnly: true,
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

class _MyInfoEditPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCheck;
  final bool isChecking;

  const _MyInfoEditPhoneField({
    required this.controller,
    required this.onCheck,
    this.isChecking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MyInfoTextField(
            controller: controller,
            keyboardType: TextInputType.phone,
          ),
        ),
        SizedBox(width: Responsive.responsiveWidth(context, 8)),
        _PhoneCheckButton(
          onTap: isChecking ? null : onCheck,
          isLoading: isChecking,
        ),
      ],
    );
  }
}

class _PhoneCheckButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _PhoneCheckButton({this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: Responsive.responsivePaddingLTRB(context, 10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFCAD8FF)),
        ),
        child: isLoading
            ? SizedBox(
                width: Responsive.responsiveIconSize(context, 14),
                height: Responsive.responsiveIconSize(context, 14),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF235DFF),
                ),
              )
            : Text(
                '번호확인',
                style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF235DFF),
                ),
              ),
      ),
    );
  }
}
