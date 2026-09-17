import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/components/glass_surface.dart';

/// [AppToast]의 종류. 아이콘/강조색을 결정한다.
enum AppToastType { info, success, error }

/// 적응형 토스트/스낵바.
///
/// iOS: 상단 안전영역 아래에 글래스 배너를 띄우고 2.5초 뒤 자동으로
/// 사라진다. VoiceOver 사용자를 위해 [SemanticsService.sendAnnouncement]로 공지한다.
/// Android: 기존 [SnackBar] 동작을 그대로 사용한다.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
  }) {
    if (isCupertino(context)) {
      _showGlassBanner(context, message, type);
    } else {
      _showSnackBar(context, message, type);
    }
  }

  static void _showSnackBar(BuildContext context, String message, AppToastType type) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _backgroundFor(type),
      ),
    );
  }

  static void _showGlassBanner(BuildContext context, String message, AppToastType type) {
    SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);

    _current?.remove();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final topPadding = MediaQuery.of(context).padding.top;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: topPadding + 8,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: GlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(type), size: 18, color: _accentFor(type)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _current = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (_current == entry) {
        entry.remove();
        _current = null;
      }
    });
  }

  static Color _backgroundFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return AppColors.success;
      case AppToastType.error:
        return AppColors.destructive;
      case AppToastType.info:
        return AppColors.label;
    }
  }

  static Color _accentFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return AppColors.success;
      case AppToastType.error:
        return AppColors.destructive;
      case AppToastType.info:
        return AppColors.primary;
    }
  }

  static IconData _iconFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle;
      case AppToastType.error:
        return Icons.error;
      case AppToastType.info:
        return Icons.info;
    }
  }
}
