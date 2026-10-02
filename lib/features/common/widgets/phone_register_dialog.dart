import 'dart:async';

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
///
/// [ensurePhoneRegistered] — 부수 효과와 주의점:
/// - 호출할 때마다 `GET /users/me`를 한다(번호가 이미 있어도). 호출하는 쪽은
///   이 네트워크 시간 동안 중복 탭을 막는 진행 중 플래그를 **호출 전에**
///   걸어야 한다.
/// - 프로필 조회가 실패하면 토스트("내 정보를 확인하지 못했어요...")를 띄우고
///   false를 돌려준다.
/// - false는 "사용자가 시트를 닫음"과 "조회 실패"를 구분하지 않는다. 어느
///   쪽이든 원래 동작을 진행하지 말아야 한다는 뜻이다.
/// - 시트에서 번호를 저장하면 서버에는 `PATCH /users/me`로 `{"phone_number"}`
///   하나만 보낸다(부분 수정). 저장이 끝난 뒤에는 시트가 어떻게 닫혔든 true다.
Future<bool> ensurePhoneRegistered(
  BuildContext context, {
  MyProfileService? profileService,
  UserService? userService,
  String? reason,
}) async {
  final service = profileService ?? MyProfileService();
  final MyProfile profile;
  try {
    profile = await service.getMyProfile();
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
    profileService: service,
    userService: userService,
    reason: reason,
  );
  return phone != null;
}

/// 번호가 없다는 전제로 등록 시트를 연다(프로필 조회는 하지 않는다). 성공하면
/// 서버에 저장된 번호(예: 010-1234-5678)를, 저장하지 않고 닫으면 null을
/// 돌려준다. 저장 중에는 사용자가 시트를 닫을 수 없다. 부수 효과: 번호 중복
/// 확인(`GET /users/check-phone`)과 `PATCH /users/me`(`{"phone_number"}`만).
Future<String?> showPhoneRegisterSheet({
  required BuildContext context,
  MyProfileService? profileService,
  UserService? userService,
  String? reason,
}) async {
  // 저장 요청이 나간 뒤 시트가 다른 경로(스와이프 등)로 먼저 닫혀도, 그
  // 저장 결과를 기다렸다가 돌려준다(서버엔 저장됐는데 false가 되지 않도록).
  Completer<String?>? saving;
  final popped = await showAppSheet<String>(
    context: context,
    builder: (_) => PhoneRegisterSheetContent(
      profileService: profileService ?? MyProfileService(),
      userService: userService ?? UserService(),
      reason: reason,
      onSaveStarted: () => saving = Completer<String?>(),
      onSaveFinished: (phone) {
        saving?.complete(phone);
        saving = null;
      },
    ),
  );
  if (popped != null) return popped;
  return saving?.future;
}

class PhoneRegisterSheetContent extends StatefulWidget {
  const PhoneRegisterSheetContent({
    super.key,
    required this.profileService,
    required this.userService,
    this.reason,
    this.onSaveStarted,
    this.onSaveFinished,
  });

  final MyProfileService profileService;
  final UserService userService;
  final String? reason;
  /// 저장 요청 직전/종료(성공 시 번호, 실패 시 null) 알림.
  final VoidCallback? onSaveStarted;
  final ValueChanged<String?>? onSaveFinished;

  @override
  State<PhoneRegisterSheetContent> createState() => _PhoneRegisterSheetContentState();
}

class _PhoneRegisterSheetContentState extends State<PhoneRegisterSheetContent> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _isSaving = false;

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

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final phone = PhoneUtil.toApiPhoneQuery(input);
    widget.onSaveStarted?.call();
    String? saved;
    try {
      if (await widget.userService.isPhoneDuplicate(input)) {
        if (!mounted) return;
        setState(() => _errorText = '이미 사용 중인 번호입니다.');
        return;
      }
      await widget.profileService.updatePhoneNumber(phone);
      saved = phone;
      // 닫힘 애니메이션 중에는 아직 mounted지만 이 시트 라우트가 맨 위가
      // 아니다. 그때 pop하면 시트 아래 라우트(앱 셸)가 pop되므로 막는다.
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop(phone);
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      setState(() {
        _errorText = status == 409
            ? '이미 사용 중인 번호입니다.'
            : status == 422
                ? '입력한 번호를 서버가 받아들이지 못했어요. 번호를 다시 확인해 주세요.'
                : '등록에 실패했어요. 다시 시도해 주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '등록에 실패했어요. 다시 시도해 주세요.');
    } finally {
      widget.onSaveFinished?.call(saved);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // iOS 전화 패드 위의 "완료" 바(44pt)가 시트 하단 버튼을 가리지 않게
    // 키보드가 올라와 있는 동안 그만큼 아래 여백을 더한다.
    final doneBarGap = isCupertino(context) && MediaQuery.viewInsetsOf(context).bottom > 0 ? 44.0 : 0.0;
    // 저장 중에는 배리어 탭/뒤로 가기로 시트가 닫히지 않게 한다.
    return PopScope(
      canPop: !_isSaving,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + doneBarGap),
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
            const SizedBox(height: 20),
            AppButton(label: '등록하기', loading: _isSaving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
