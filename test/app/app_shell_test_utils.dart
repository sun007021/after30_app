import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';

/// 셸 테스트에서 실제 기능 화면(네트워크/Firebase/카카오 필요) 대신 쓰는
/// 가벼운 스텁 페이지. 탭 인덱스별로 다른 라벨을 달고, 내부에 카운터를 둬서
/// 탭 전환 시 상태(스크롤 위치 등에 준하는 로컬 state)가 보존되는지
/// 확인할 수 있게 한다.
class CounterStubPage extends StatefulWidget {
  const CounterStubPage({super.key, required this.tag});

  final String tag;

  @override
  State<CounterStubPage> createState() => CounterStubPageState();
}

class CounterStubPageState extends State<CounterStubPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.tag}:$count'),
            ElevatedButton(
              onPressed: () => setState(() => count++),
              child: const Text('+1'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('${widget.tag}-sub')),
                    body: Center(child: Text('${widget.tag}-sub-page')),
                  ),
                ),
              ),
              child: const Text('push sub'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 테스트용 탭 빌더 5개(순서는 [AppShellTab]과 같다). `arguments`가 오면
/// 라벨에 그대로 반영해 `switchTab(arguments: ...)` 테스트에도 쓸 수 있다.
List<AppShellPageBuilder> testPageBuilders() {
  const tags = ['alarm', 'family', 'home', 'history', 'my'];
  return List.generate(tags.length, (i) {
    return (context, args) {
      final tag = args == null ? tags[i] : '${tags[i]}-$args';
      return CounterStubPage(key: ValueKey('stub-$i-$tag'), tag: tag);
    };
  });
}

/// 지정한 [platform]으로 [AppShell]을 펌프한다.
Future<void> pumpAppShell(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  int initialIndex = AppShellTab.home,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: AppShell(initialIndex: initialIndex, pageBuilders: testPageBuilders()),
    ),
  );
  await tester.pump();
}
