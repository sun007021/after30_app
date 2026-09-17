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
}
