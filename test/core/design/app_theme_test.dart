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

    expect(find.byType(CupertinoPageTransition), findsNothing);
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('다음 화면'), findsOneWidget);
  });
}
