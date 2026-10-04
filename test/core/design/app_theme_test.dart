import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';

/// [AppTheme]가 iOS 페이지 전환에서 "동작 줄이기"(reduce motion) 설정을
/// 존중하는지 검증한다(§4.3: `MediaQuery.disableAnimationsOf`가 켜져 있으면
/// 슬라이드 대신 크로스페이드로 대체).
void main() {
  Widget buildApp({required bool disableAnimations}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('다음 화면')),
            ),
            child: const Text('이동'),
          ),
        ),
      ),
    );
  }

  testWidgets('동작 줄이기가 꺼져 있으면 기존 Cupertino 슬라이드 전환을 사용한다', (tester) async {
    await tester.pumpWidget(buildApp(disableAnimations: false));

    await tester.tap(find.text('이동'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CupertinoPageTransition), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('동작 줄이기가 켜져 있으면 슬라이드 대신 페이드 전환을 사용한다', (tester) async {
    await tester.pumpWidget(buildApp(disableAnimations: true));

    await tester.tap(find.text('이동'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 슬라이드가 없으므로 전환 중에도 화면이 최종 위치(x=0)에 있다.
    expect(tester.getTopLeft(find.text('다음 화면')).dx, 0);
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('다음 화면'), findsOneWidget);
  });

  testWidgets('동작 줄이기가 켜져 있어도 엣지 스와이프로 뒤로 간다', (tester) async {
    await tester.pumpWidget(buildApp(disableAnimations: true));
    await tester.tap(find.text('이동'));
    await tester.pumpAndSettle();
    expect(find.text('다음 화면'), findsOneWidget);

    await tester.dragFrom(const Offset(3, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('다음 화면'), findsNothing);
    expect(find.text('이동'), findsOneWidget);
  });

  testWidgets('동작 줄이기가 꺼져 있어도 엣지 스와이프로 뒤로 간다', (tester) async {
    await tester.pumpWidget(buildApp(disableAnimations: false));
    await tester.tap(find.text('이동'));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(3, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('다음 화면'), findsNothing);
  });
}
