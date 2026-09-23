// 디버그 전용 프리뷰 엔트리포인트(plan §6 W10 검증 절차).
//
// `flutter build ios --simulator`가 Xcode 26.6 + Flutter 3.38.3 조합에서
// lipo 오류로 실패하기 때문에(plan §3 완료 조건 각주), 이 파일로
// `flutter run -t lib/dev/shell_preview_main.dart`를 실행해 앱 셸만 빠르게
// 확인한다. Firebase/Kakao/AlarmService 초기화를 전혀 하지 않고, 탭
// 콘텐츠도 스크롤 확인용 스텁 리스트로 대체한다. 릴리스 빌드 진입점이
// 아니므로 `main.dart`에서 import하지 않는다. (리뷰 nit: lib/app/에서
// lib/dev/로 이동 — 이 파일은 셸 자체가 아니라 셸을 확인하기 위한 개발용
// 도구다.)
import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/common/navigationBar.dart';

void main() {
  runApp(const _ShellPreviewApp());
}

class _ShellPreviewApp extends StatelessWidget {
  const _ShellPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '앱 셸 프리뷰',
      theme: AppTheme.build(),
      home: AppShell(pageBuilders: List.generate(5, (i) {
        return (context, args) => _PreviewTabPage(index: i);
      })),
      debugShowCheckedModeBanner: false,
    );
  }
}

const _tabLabels = ['알람', '가족', '홈', '기록', '마이'];

/// 탭마다 다른 색과 긴 스크롤 목록을 보여주는 스텁 페이지.
/// - 글래스 탭바 아래로 콘텐츠가 얼마나 스크롤되는지
/// - 탭 전환 시 스크롤 위치가 유지되는지
/// - 서브 페이지로 push했을 때 iOS 엣지 스와이프 백이 동작하는지
/// - 실제 화면들처럼 `bottomNavigationBar: AlarmBottomNavigation(...)`을
///   그대로 쓸 때 마지막 항목이 탭바에 가려지지 않는지(B3)
/// 를 눈으로 확인하는 용도다. 홈 탭(index==AppShellTab.home)에서는
/// 시뮬레이터 스크린샷 검증을 손으로 탭하지 않고도 찍을 수 있도록 일정
/// 시간 뒤 자동으로 스크롤하고 서브 페이지를 연다("서브 페이지 열기"
/// 버튼으로 수동으로도 열 수 있다).
class _PreviewTabPage extends StatefulWidget {
  const _PreviewTabPage({required this.index});

  final int index;

  @override
  State<_PreviewTabPage> createState() => _PreviewTabPageState();
}

class _PreviewTabPageState extends State<_PreviewTabPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.index == AppShellTab.home) {
      Future.delayed(const Duration(seconds: 6), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          900,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
      Future.delayed(const Duration(seconds: 12), _openSubPage);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openSubPage() {
    if (!mounted) return;
    final label = _tabLabels[widget.index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('$label 서브 페이지')),
          // 실제 화면들처럼 탭 안에서 push된 서브 페이지도 탭바를 그대로
          // 쓴다(iOS 컨벤션: 탭 내 push에서는 탭바가 계속 보인다, B3).
          bottomNavigationBar: AlarmBottomNavigation(currentIndex: widget.index),
          body: Center(
            child: Text(
              '엣지 스와이프로 뒤로 갈 수 있어야 합니다',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _tabLabels[widget.index];
    return Scaffold(
      appBar: AppBar(title: Text('$label 탭 프리뷰')),
      // 실제 화면들처럼 bottomNavigationBar: AlarmBottomNavigation(...)을
      // 그대로 써서, 셸 안에서 탭바에 콘텐츠가 가려지지 않는지(B3)를
      // 프리뷰에서도 검증할 수 있게 한다.
      bottomNavigationBar: AlarmBottomNavigation(currentIndex: widget.index),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 60,
        itemBuilder: (context, i) {
          final isLast = i == 59;
          return ListTile(
            title: Text('$label 항목 $i'),
            trailing: i == 0
                ? FilledButton(
                    onPressed: _openSubPage,
                    child: const Text('서브 페이지 열기'),
                  )
                : isLast
                ? const Text('마지막 항목', style: TextStyle(fontWeight: FontWeight.bold))
                : null,
          );
        },
      ),
    );
  }
}
