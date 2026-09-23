import 'package:after30/features/family/ui/widgets/family_phone_register_popup.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/app/app_shell.dart';
import 'package:flutter/material.dart';

class PhoneRegisterDialog {
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onCancel,
    required VoidCallback onGoToMyPage,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x80C8C8C8),
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: FamilyPhoneRegisterPopup(
            onCancel: () {
              Navigator.of(dialogContext).pop();
              onCancel();
            },
            onGoToMyPage: () {
              Navigator.of(dialogContext).pop();
              onGoToMyPage();
            },
          ),
        );
      },
    );
  }

  static Future<void> checkAndShowIfNeeded(BuildContext context) async {
    try {
      final profile = await MyProfileService().getMyProfile();
      if (!context.mounted || profile.hasPhoneNumber) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        show(
          context: context,
          onCancel: () {},
          onGoToMyPage: () {
            // 앱 셸 안에서는 마이페이지 탭으로 전환한다(plan §6 W10 5항).
            AppShell.of(context).switchTab(AppShellTab.my);
          },
        );
      });
    } catch (_) {}
  }
}
