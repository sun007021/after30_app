import 'package:after30/features/family/ui/widgets/family_phone_register_popup.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/my_page.dart';
import 'package:flutter/material.dart';

class PhoneRegisterDialog {
  static PageRouteBuilder<void> _noAnimRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

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
            Navigator.of(context).pushReplacement(_noAnimRoute(const MyPage()));
          },
        );
      });
    } catch (_) {}
  }
}
