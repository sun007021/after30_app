import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/common/navigationBar.dart';

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

/// B2(IndexedStack이 방문하지 않은 탭까지 한꺼번에 만드는 문제) 테스트용
/// 스텁. 첫 프레임 직후 initState에서 예약한 다이얼로그를 띄운다 —
/// FamilyPage가 initState에서 전화번호 등록 팝업을 예약하는 것과 같은
/// 모양이다. 다이얼로그 안 텍스트로 [tag]를 그대로 써서 어느 탭에서 뜬
/// 다이얼로그인지 구분할 수 있게 한다.
class DialogOnInitPage extends StatefulWidget {
  const DialogOnInitPage({super.key, required this.tag});

  final String tag;

  @override
  State<DialogOnInitPage> createState() => _DialogOnInitPageState();
}

class _DialogOnInitPageState extends State<DialogOnInitPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(content: Text('${widget.tag}-popup')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(widget.tag)));
  }
}

/// B3(콘텐츠가 탭바에 가려짐)/M1(SnackBar가 탭바 아래 깔림) 테스트용 스텁.
/// 실제 화면들처럼 `bottomNavigationBar: AlarmBottomNavigation(...)`을
/// 그대로 쓰고, 끝까지 스크롤해야 보이는 마지막 항목에 탭 가능한 버튼을
/// 둬서 "탭바에 가려 눌리지 않는다" 회귀를 잡을 수 있게 한다. 버튼을
/// 누르면 SnackBar도 띄워, 그 SnackBar가 탭바 아래 깔리지 않는지도 같이
/// 확인할 수 있다.
class ScaffoldWithListPage extends StatelessWidget {
  const ScaffoldWithListPage({
    super.key,
    required this.currentIndex,
    this.itemCount = 40,
  });

  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AlarmBottomNavigation(currentIndex: currentIndex),
      body: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, i) {
          final isLast = i == itemCount - 1;
          if (!isLast) {
            return ListTile(title: Text('item-$i'));
          }
          return ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('last-item-snackbar')));
            },
            child: const Text('last-item-button'),
          );
        },
      ),
    );
  }
}

/// N1 테스트용 스텁: `bottomNavigationBar`가 아예 없는 "서브 페이지"
/// 흉내(예: `add_alarm.dart`처럼 원래 탭바가 없던 화면). 평범한 `SafeArea`
/// 하나만 쓴다 — 셸 안에서든 밖에서든 특별한 처리를 하지 않는, 실제로
/// 흔히 볼 수 있는 화면 모양이다. 이게 저절로 탭바/키보드를 피하는 이유는
/// (특별한 로직이 있어서가 아니라) 키보드가 올라오면 iOS가
/// `padding.bottom`을 0으로 보고하기 때문이다(홈 인디케이터 세이프
/// 에어리어를 키보드가 대신 차지) — `SafeArea`가 그 값을 그대로 읽어서
/// 자동으로 맞아떨어진다.
class SubPageCtaNoBottomBar extends StatelessWidget {
  const SubPageCtaNoBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            const TextField(key: Key('sub-page-textfield')),
            ElevatedButton(onPressed: () {}, child: const Text('sub-page-cta')),
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
