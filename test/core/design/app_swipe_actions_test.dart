import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('Android에서는 Dismissible로 렌더링되고 스와이프하면 삭제 콜백이 호출된다', (tester) async {
    var deleted = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(
        child: AppSwipeActions(
          itemKey: const ValueKey('row-1'),
          onDelete: () => deleted = true,
          child: const SizedBox(height: 48, child: Text('항목')),
        ),
      ),
    );

    expect(find.byType(Dismissible), findsOneWidget);
    await tester.drag(find.text('항목'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('iOS에서는 Dismissible 없이 드래그로 삭제 버튼을 노출한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSwipeActions(
          itemKey: const ValueKey('row-1'),
          onDelete: () {},
          child: const SizedBox(height: 48, width: 300, child: Text('항목')),
        ),
      ),
    );

    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('삭제'), findsOneWidget);
  });
}
