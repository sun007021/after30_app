import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/double_check_dialog.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/family/ui/widgets/invite_phone_lookup_error_popup.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/utils/responsive.dart';

class FamilyInviteExistingGroupInvitePage extends StatefulWidget {
  final int? groupId;
  final String groupName;

  const FamilyInviteExistingGroupInvitePage({
    super.key,
    this.groupId,
    required this.groupName,
  });

  bool get isNewGroup => groupId == null;

  @override
  State<FamilyInviteExistingGroupInvitePage> createState() =>
      _FamilyInviteExistingGroupInvitePageState();
}

class _InvitePhoneEntry {
  const _InvitePhoneEntry({required this.phone, required this.label});

  final String phone;
  final String label;
}

class _FamilyInviteExistingGroupInvitePageState
    extends State<FamilyInviteExistingGroupInvitePage> {
  final TextEditingController _phoneController = TextEditingController();
  final FamilyService _familyService = FamilyService();
  final UserService _userService = UserService();
  final List<_InvitePhoneEntry> _entries = [];
  bool _isSending = false;
  bool _isLookingUp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDisplayPhone(String normalized) {
    if (!normalized.startsWith('+82')) return normalized;
    final local = '0${normalized.substring(3)}';
    if (local.length == 11) {
      return '${local.substring(0, 3)}-${local.substring(3, 7)}-${local.substring(7)}';
    }
    return local;
  }

  Future<void> _addPhoneFromInput({required String raw, String? label}) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      await _showMessageDialog('전화번호를 입력해 주세요.');
      return;
    }

    final normalized = PhoneUtil.normalizePhoneNumber(trimmed);
    if (!PhoneUtil.isValidPhoneNumber(normalized)) {
      await _showMessageDialog('유효한 전화번호 형식이 아닙니다.');
      return;
    }

    if (_entries.any((entry) => entry.phone == normalized)) {
      await _showMessageDialog('이미 추가된 번호입니다.');
      return;
    }

    setState(() => _isLookingUp = true);
    try {
      final lookup = await _userService.getUserByPhone(normalized);

      if (!lookup.exists) {
        if (!mounted) return;
        await _showLookupErrorDialog();
        return;
      }

      final apiName = lookup.name?.trim();
      final displayLabel = apiName != null && apiName.isNotEmpty
          ? apiName
          : label?.trim().isNotEmpty == true
          ? label!.trim()
          : _formatDisplayPhone(normalized);

      if (!mounted) return;
      setState(() {
        _entries.add(_InvitePhoneEntry(phone: normalized, label: displayLabel));
        _phoneController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      await _showLookupErrorDialog();
    } finally {
      if (mounted) {
        setState(() => _isLookingUp = false);
      }
    }
  }

  Future<void> _addPhone() async {
    await _addPhoneFromInput(raw: _phoneController.text);
  }

  Future<void> _inviteAll() async {
    if (_entries.isEmpty) {
      await _showMessageDialog('초대할 전화번호를 추가해 주세요.');
      return;
    }

    setState(() => _isSending = true);
    try {
      var groupId = widget.groupId;
      if (groupId == null) {
        final group = await _familyService.createGroup(widget.groupName);
        groupId = group.id;
      }

      for (final entry in _entries) {
        await _familyService.sendInvitation(
          groupId: groupId,
          inviteePhoneNumber: entry.phone,
        );
      }
      if (!mounted) return;
      await _showMessageDialog('초대를 전송했습니다.');
      if (!mounted) return;
      _navigateToFamilyMain(groupId);
    } catch (_) {
      if (!mounted) return;
      await _showMessageDialog(
        widget.isNewGroup ? '그룹 생성 또는 초대 전송에 실패했습니다.' : '초대 전송에 실패했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _showLookupErrorDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x80C8C8C8),
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: InvitePhoneLookupErrorPopup(
            onConfirm: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  Future<void> _showMessageDialog(String message) async {
    if (!mounted) return;
    await DoubleCheckDialog.showSingle(
      context: context,
      title: '알림',
      message: message,
      confirmLabel: '확인',
    );
  }

  void _navigateToFamilyMain(int groupId) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => FamilyPage(initialGroupId: groupId),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      20,
                      0,
                      20,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              color: const Color(0xFF111111),
                              size: Responsive.responsiveIconSize(context, 18),
                            ),
                          ),
                        ),
                        const StepHeader(
                          currentStep: 3,
                          step1Label: '',
                          step2Label: '',
                          step3Label: '',
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 12),
                        ),
                        Padding(
                          padding: Responsive.responsivePaddingLTRB(
                            context,
                            28,
                            0,
                            0,
                            0,
                          ),
                          child: Text(
                            widget.isNewGroup
                                ? '3. 새 그룹 가족 초대'
                                : '3. 기존 그룹 가족 초대',
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(
                                context,
                                20,
                              ),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 24),
                        ),
                        Padding(
                          padding: Responsive.responsivePaddingLTRB(
                            context,
                            28,
                            0,
                            0,
                            0,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: Responsive.responsiveFontSize(
                                  context,
                                  16,
                                ),
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.w600,
                              ),
                              children: const [
                                TextSpan(
                                  text: '·',
                                  style: TextStyle(color: Color(0xFF235DFF)),
                                ),
                                TextSpan(text: '그룹 이름'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 12),
                        ),
                        Padding(
                          padding: Responsive.responsivePaddingLTRB(
                            context,
                            28,
                            0,
                            28,
                            0,
                          ),
                          child: SizedBox(
                            height: Responsive.responsiveHeight(context, 66),
                            child: TextFormField(
                              readOnly: true,
                              initialValue: widget.groupName,
                              decoration: _fieldDecoration(
                                context: context,
                                hintText: widget.groupName,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 20),
                        ),
                        Padding(
                          padding: Responsive.responsivePaddingLTRB(
                            context,
                            28,
                            0,
                            0,
                            0,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: Responsive.responsiveFontSize(
                                  context,
                                  16,
                                ),
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.w600,
                              ),
                              children: const [
                                TextSpan(
                                  text: '·',
                                  style: TextStyle(color: Color(0xFF235DFF)),
                                ),
                                TextSpan(text: '초대할 가족 전화번호'),
                              ],
                            ),
                          ),
                        ),
                        if (_entries.isNotEmpty) ...[
                          SizedBox(
                            height: Responsive.responsiveHeight(context, 12),
                          ),
                          Padding(
                            padding: Responsive.responsivePaddingLTRB(
                              context,
                              28,
                              0,
                              28,
                              0,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _entries.map((entry) {
                                return _PhoneInviteChip(
                                  label: entry.label,
                                  onRemove: () {
                                    setState(() {
                                      _entries.removeWhere(
                                        (item) => item.phone == entry.phone,
                                      );
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        SizedBox(
                          height: Responsive.responsiveHeight(context, 12),
                        ),
                        Padding(
                          padding: Responsive.responsivePaddingLTRB(
                            context,
                            28,
                            0,
                            28,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: Responsive.responsiveHeight(context, 66),
                                child: TextField(
                                  controller: _phoneController,
                                  enabled: !_isLookingUp && !_isSending,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _addPhone(),
                                  decoration: _fieldDecoration(
                                    context: context,
                                    hintText: '010-XXXX-XXXX',
                                    suffix: _isLookingUp
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: Responsive.responsivePaddingLTRB(
                    context,
                    48,
                    0,
                    48,
                    68,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: Responsive.responsiveHeight(context, 40),
                    child: ElevatedButton(
                      onPressed: _isSending || _isLookingUp ? null : _inviteAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF235DFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '초대 하기',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
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
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hintText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 16),
        color: const Color(0xFF949494),
        fontWeight: FontWeight.w400,
      ),
      contentPadding: Responsive.responsivePaddingLTRB(context, 24, 16, 16, 16),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
    );
  }
}

class _PhoneInviteChip extends StatelessWidget {
  const _PhoneInviteChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.fromLTRB(14, 5, 7, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 16),
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 21,
              height: 21,
              child: Icon(Icons.close, size: 15, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
