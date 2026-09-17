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

    // my_info_widgets.dart의 MyInfoHeader와 동일한 아이콘을 쓴다.
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
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

  testWidgets('컴팩트 제목은 한 줄로 말줄임 처리된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      const Scaffold(
        appBar: AppNavBar(title: '아주 아주 아주 아주 긴 화면 제목입니다', showBackButton: false),
      ),
    );
    final text = tester.widget<Text>(find.textContaining('아주'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  group('AppSliverNavBar', () {
    testWidgets('iOS에서는 CupertinoSliverNavigationBar를 사용한다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        CustomScrollView(
          slivers: [
            const AppSliverNavBar(title: '홈', showBackButton: false),
            SliverToBoxAdapter(child: Container(height: 2000)),
          ],
        ),
      );
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(find.text('홈'), findsOneWidget);
    });

    testWidgets('Android에서는 SliverAppBar를 사용한다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        CustomScrollView(
          slivers: [
            const AppSliverNavBar(title: '홈', showBackButton: false),
            SliverToBoxAdapter(child: Container(height: 2000)),
          ],
        ),
      );
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
      expect(find.text('홈'), findsOneWidget);
    });

    testWidgets('뒤로가기 버튼을 탭하면 onBack이 호출된다(Android)', (tester) async {
      var tapped = false;
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        CustomScrollView(
          slivers: [
            AppSliverNavBar(title: '상세', onBack: () => tapped = true),
            const SliverToBoxAdapter(child: SizedBox()),
          ],
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
