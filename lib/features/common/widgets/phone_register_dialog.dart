import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';

/// 전화번호 등록 시트(plan §2 D11).
///
/// 가족 탭에 들어올 때 강제로 띄우던 모달 대신, 전화번호가 꼭 필요한 동작
/// (그룹 생성, 초대 전송, 초대 수락)을 하려는 순간에만 그 자리에서 열리는
/// 바텀 시트다. 등록에 성공하면 호출한 쪽이 원래 동작을 이어서 실행한다.
///
/// 다른 화면(예: W9 마이페이지의 "미등록" 진입점)도 아래 두 함수를 그대로
/// 호출하면 된다.
/// - [ensurePhoneRegistered]: 프로필을 조회해 번호가 이미 있으면 true,
///   없으면 시트를 열어 등록 결과를 true/false로 돌려준다.
/// - [showPhoneRegisterSheet]: 이미 프로필을 가진 쪽에서 시트만 열고 싶을 때.
///   등록된 번호(저장 형식, 예: 010-1234-5678) 또는 취소 시 null을 돌려준다.
Future<bool> ensurePhoneRegistered(
  BuildContext context, {
  MyProfileService? profileService,
  UserService? userService,
  String? reason,
}) async {
  final MyProfile profile;
  try {
    profile = await (profileService ?? MyProfileService()).getMyProfile();
  } catch (_) {
    if (context.mounted) {
      AppToast.show(context, '내 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.', type: AppToastType.error);
    }
    return false;
  }
  if (profile.hasPhoneNumber) return true;
  if (!context.mounted) return false;
  final phone = await showPhoneRegisterSheet(
    context: context,
    profile: profile,
    profileService: profileService,
    userService: userService,
    reason: reason,
  );
  return phone != null;
}

/// [profile]에 번호가 없다는 전제로 등록 시트를 연다. 성공하면 저장된 번호를,
/// 취소/닫기면 null을 돌려준다.
Future<String?> showPhoneRegisterSheet({
  required BuildContext context,
  required MyProfile profile,
  MyProfileService? profileService,
  UserService? userService,
  String? reason,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => PhoneRegisterSheetContent(
      profile: profile,
      profileService: profileService ?? MyProfileService(),
      userService: userService ?? UserService(),
      reason: reason,
    ),
  );
}

class PhoneRegisterSheetContent extends StatefulWidget {
  const PhoneRegisterSheetContent({
    super.key,
    required this.profile,
    required this.profileService,
    required this.userService,
    this.reason,
  });

  final MyProfile profile;
  final MyProfileService profileService;
  final UserService userService;
  final String? reason;

  @override
  State<PhoneRegisterSheetContent> createState() => _PhoneRegisterSheetContentState();
}

class _PhoneRegisterSheetContentState extends State<PhoneRegisterSheetContent> {
  final TextEditingController _controller = TextEditingController();
  String? _gender;
  String? _errorText;
  bool _isSaving = false;

  /// 프로필에 성별이 없으면 PATCH가 거절될 수 있어 시트 안에서 같이 받는다.
  bool get _needsGender => (widget.profile.gender ?? '').trim().isEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = '전화번호를 입력해 주세요.');
      return;
    }
    if (!PhoneUtil.isValidPhoneNumber(input)) {
      setState(() => _errorText = '유효한 전화번호 형식이 아닙니다.');
      return;
    }
    if (_needsGender && _gender == null) {
      setState(() => _errorText = '성별을 선택해 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final phone = PhoneUtil.toApiPhoneQuery(input);
    try {
      if (await widget.userService.isPhoneDuplicate(input)) {
        if (!mounted) return;
        setState(() => _errorText = '이미 사용 중인 번호입니다.');
        return;
      }
      await widget.profileService.updateMyProfile(
        name: widget.profile.name ?? '',
        gender: _needsGender ? _gender! : widget.profile.gender!,
        phoneNumber: phone,
      );
      if (!mounted) return;
      Navigator.of(context).pop(phone);
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      setState(() {
        _errorText = status == 409
            ? '이미 사용 중인 번호입니다.'
            : status == 422
                ? '전화번호 형식이 올바르지 않습니다.'
                : '등록에 실패했어요. 다시 시도해 주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '등록에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '전화번호를 등록해 주세요',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reason ?? '가족이 나를 초대하고 내가 가족을 초대하려면 전화번호가 필요해요.',
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.secondaryLabel),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _controller,
            placeholder: '010-0000-0000',
            keyboardType: TextInputType.phone,
            showKeyboardDoneBar: true,
            inputFormatters: [PhoneNumberFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
            errorText: _errorText,
            enabled: !_isSaving,
            autofocus: true,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          if (_needsGender) ...[
            const SizedBox(height: 16),
            AppSegmentedControl<String>(
              options: const [
                AppSegmentedOption(value: '남', label: '남'),
                AppSegmentedOption(value: '여', label: '여'),
              ],
              value: _gender,
              onChanged: (value) => setState(() {
                _gender = value;
                _errorText = null;
              }),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(label: '등록하기', loading: _isSaving, onPressed: _submit),
        ],
      ),
    );
  }
}
