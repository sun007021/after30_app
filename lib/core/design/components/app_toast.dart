import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/components/glass_surface.dart';

/// [AppToast]의 종류. 아이콘/강조색을 결정한다.
enum AppToastType { info, success, error }

/// 적응형 토스트/스낵바.
///
/// iOS: 상단 안전영역 아래에 글래스 배너를 페이드+슬라이드로 띄우고 2.5초
/// 뒤 자동으로 사라진다(탭하면 즉시 닫힘). VoiceOver 사용자를 위해
/// [SemanticsService.sendAnnouncement]로 공지한다.
/// Android: 기존 [SnackBar] 동작(기본 M3 스타일)을 그대로 사용한다.
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
      _showSnackBar(context, message);
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    // 기존 25곳의 SnackBar 호출부와 동일하게 M3 기본 색상을 유지한다.
    // type에 따라 배경색을 바꾸면 Android 화면 외형이 달라지므로 넣지 않는다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static void _showGlassBanner(BuildContext context, String message, AppToastType type) {
    SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);

    // 이전 배너가 아직 떠 있다면 애니메이션 없이 즉시 정리한다(타이머/오버레이
    // 중복 방지).
    _current?.remove();
    _current = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final topPadding = MediaQuery.of(context).padding.top;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: topPadding + 8,
        left: 16,
        right: 16,
        child: _GlassBanner(
          message: message,
          type: type,
          onDismissed: () {
            if (_current == entry) _current = null;
            entry.remove();
          },
        ),
      ),
    );

    _current = entry;
    overlay.insert(entry);
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

/// 글래스 배너의 페이드+슬라이드 인/아웃 애니메이션과 자동 소멸 타이머를
/// 관리하는 위젯. 탭하면 타이머를 취소하고 즉시 닫힌다.
class _GlassBanner extends StatefulWidget {
  const _GlassBanner({required this.message, required this.type, required this.onDismissed});

  final String message;
  final AppToastType type;
  final VoidCallback onDismissed;

  @override
  State<_GlassBanner> createState() => _GlassBannerState();
}

class _GlassBannerState extends State<_GlassBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _autoDismissTimer = Timer(const Duration(milliseconds: 2500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: GlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppToast._iconFor(widget.type), size: 18, color: AppToast._accentFor(widget.type)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
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
  }
}
