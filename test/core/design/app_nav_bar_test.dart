import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 셰브론 뒤로가기 아이콘을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(appBar: AppNavBar(title: '제목', onBack: () {})),
    );

    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.text('제목'), findsOneWidget);
  });

  testWidgets('Android에서는 화살표 뒤로가기 아이콘을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Scaffold(appBar: AppNavBar(title: '제목', onBack: () {})),
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
  });

  testWidgets('showBackButton이 false면 뒤로가기 버튼이 없다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      const Scaffold(appBar: AppNavBar(title: '홈', showBackButton: false)),
    );
    expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
  });

  testWidgets('largeTitle 모드에서는 큰 제목이 추가로 표시된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      const Scaffold(
        appBar: AppNavBar(title: '홈', showBackButton: false, largeTitle: true),
      ),
    );
    expect(find.text('홈'), findsNWidgets(1));
  });
}
