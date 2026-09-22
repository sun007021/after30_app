// 디버그 전용 프리뷰 엔트리포인트(plan §6 W10 검증 절차).
//
// `flutter build ios --simulator`가 Xcode 26.6 + Flutter 3.38.3 조합에서
// lipo 오류로 실패하기 때문에(plan §3 완료 조건 각주), 이 파일로
// `flutter run -t lib/app/shell_preview_main.dart`를 실행해 앱 셸만 빠르게
// 확인한다. Firebase/Kakao/AlarmService 초기화를 전혀 하지 않고, 탭
// 콘텐츠도 스크롤 확인용 스텁 리스트로 대체한다. 릴리스 빌드 진입점이
// 아니므로 `main.dart`에서 import하지 않는다.
import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';

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
/// 를 눈으로 확인하는 용도다.
class _PreviewTabPage extends StatelessWidget {
  const _PreviewTabPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final label = _tabLabels[index];
    return Scaffold(
      appBar: AppBar(title: Text('$label 탭 프리뷰')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 60,
        itemBuilder: (context, i) {
          return ListTile(
            title: Text('$label 항목 $i'),
            trailing: i == 0
                ? FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('$label 서브 페이지')),
                          body: Center(
                            child: Text(
                              '엣지 스와이프로 뒤로 갈 수 있어야 합니다',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('서브 페이지 열기'),
                  )
                : null,
          );
        },
      ),
    );
  }
}
