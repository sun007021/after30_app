import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('destructive 타일은 빨간 텍스트로 표시된다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppGroupedSection(
          children: [
            AppListTile(title: '로그아웃', destructive: true, onTap: () {}),
          ],
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('로그아웃'));
    expect(text.style?.color, AppColors.destructive);
  });

  testWidgets('showChevron이 true면 셰브론 아이콘을 그린다(iOS)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppGroupedSection(
          children: [AppListTile(title: '설정', showChevron: true, onTap: () {})],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
  });

  testWidgets('탭하면 onTap 콜백이 호출된다', (tester) async {
    var tapped = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppGroupedSection(
          children: [AppListTile(title: '알람', onTap: () => tapped = true)],
        ),
      ),
    );

    await tester.tap(find.text('알람'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('iOS에서는 연속 곡률(ClipRSuperellipse)로 클리핑한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppGroupedSection(children: [AppListTile(title: '설정', onTap: () {})]),
      ),
    );
    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
  });

  testWidgets('Android에서는 일반 사각 곡률(ClipRRect)로 클리핑한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppGroupedSection(children: [AppListTile(title: '설정', onTap: () {})]),
      ),
    );
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(ClipRSuperellipse), findsNothing);
  });

  testWidgets('Android에서는 행 사이 구분선을 그리지 않는다(link_list.dart와 동일)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppGroupedSection(
          children: [
            AppListTile(title: '첫 번째', onTap: () {}),
            AppListTile(title: '두 번째', onTap: () {}),
          ],
        ),
      ),
    );
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('iOS에서는 행 사이 구분선을 그리고, leading이 있으면 들여쓰기가 커진다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppGroupedSection(
          children: [
            AppListTile(
              title: '아이콘 있는 행',
              leading: const Icon(Icons.star, size: 24),
              onTap: () {},
            ),
            AppListTile(title: '두 번째', onTap: () {}),
            AppListTile(title: '세 번째', onTap: () {}),
          ],
        ),
      ),
    );

    final dividers = tester.widgetList<Padding>(
      find.ancestor(of: find.byType(Divider), matching: find.byType(Padding)),
    );
    final insets = dividers.map((p) => (p.padding as EdgeInsets).left).toList();
    // 첫 번째 구분선은 leading(24) + 간격(12) + 기본 16을 더해 더 깊게
    // 들여써야 하고, 두 번째 구분선은 leading이 없으므로 기본 16이어야 한다.
    expect(insets[0], 16 + 24 + 12);
    expect(insets[1], 16);
  });

  testWidgets('행은 로컬 Material로 감싸져 있어 InkWell 잉크가 올바른 레이어에 그려진다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppGroupedSection(children: [AppListTile(title: '설정', onTap: () {})]),
      ),
    );
    final inkWellFinder = find.byType(InkWell);
    expect(find.ancestor(of: inkWellFinder, matching: find.byType(Material)), findsWidgets);
  });
}
