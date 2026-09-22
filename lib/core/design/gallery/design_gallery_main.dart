import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/core/design/gallery/design_gallery_page.dart';

/// 디자인 갤러리 전용 엔트리포인트.
///
/// Firebase/Kakao 초기화 없이 디자인 시스템만 확인할 수 있게 분리한
/// 실행 파일이다. 실행 예:
/// `flutter run -t lib/core/design/gallery/design_gallery_main.dart`
///
/// 화면 우측 상단 버튼으로 [ThemeData.platform]을 iOS/Android로 전환해
/// 같은 화면에서 두 플랫폼의 분기를 비교할 수 있다.
void main() {
  runApp(const DesignGalleryApp());
}

class DesignGalleryApp extends StatefulWidget {
  const DesignGalleryApp({super.key});

  @override
  State<DesignGalleryApp> createState() => _DesignGalleryAppState();
}

class _DesignGalleryAppState extends State<DesignGalleryApp> {
  TargetPlatform _platform = TargetPlatform.iOS;

  void _togglePlatform() {
    setState(() {
      _platform = _platform == TargetPlatform.iOS ? TargetPlatform.android : TargetPlatform.iOS;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build().copyWith(platform: _platform);

    return MaterialApp(
      title: '디자인 갤러리',
      theme: theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      home: _PlatformToggleScaffold(platform: _platform, onToggle: _togglePlatform),
    );
  }
}

/// [DesignGalleryPage] 위에 플랫폼 토글 버튼을 얹은 래퍼.
class _PlatformToggleScaffold extends StatelessWidget {
  const _PlatformToggleScaffold({required this.platform, required this.onToggle});

  final TargetPlatform platform;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DesignGalleryPage(),
        Positioned(
          top: 48,
          right: 16,
          child: SafeArea(
            child: FloatingActionButton.small(
              heroTag: 'platform-toggle',
              onPressed: onToggle,
              child: Text(platform == TargetPlatform.iOS ? 'iOS' : 'AOS'),
            ),
          ),
        ),
      ],
    );
  }
}
