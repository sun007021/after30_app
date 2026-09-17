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
          itemKey: const ValueKey('row-swipe-1'),
          onDelete: () {},
          child: const SizedBox(height: 48, width: 300, child: Text('항목')),
        ),
      ),
    );

    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('iOS: 절반 이상 드래그해서 열면 삭제 버튼이 탭 가능해지고 onDelete가 호출된다', (tester) async {
    var deleted = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSwipeActions(
          itemKey: const ValueKey('row-swipe-2'),
          onDelete: () => deleted = true,
          child: const SizedBox(height: 48, width: 300, child: Text('항목2')),
        ),
      ),
    );

    // 액션 너비(72pt)의 절반을 넘겨 드래그한 뒤 놓으면 완전히 열려야 한다.
    await tester.drag(find.text('항목2'), const Offset(-100, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('iOS: 절반 미만 드래그 후 놓으면 다시 닫힌다(삭제 버튼이 가려짐)', (tester) async {
    var deleted = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSwipeActions(
          itemKey: const ValueKey('row-swipe-3'),
          onDelete: () => deleted = true,
          child: const SizedBox(height: 48, width: 300, child: Text('항목3')),
        ),
      ),
    );

    await tester.drag(find.text('항목3'), const Offset(-20, 0));
    await tester.pumpAndSettle();

    // 닫힌 상태이므로 삭제 버튼 영역이 본문에 가려져 탭이 본문(닫기)으로
    // 처리되고 onDelete는 호출되지 않아야 한다.
    await tester.tap(find.text('항목3'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
  });

  testWidgets('iOS: 짧은 거리라도 빠르게 플링하면 열린다(속도 우선)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: AppSwipeActions(
          itemKey: const ValueKey('row-swipe-4'),
          onDelete: () {},
          child: const SizedBox(height: 48, width: 300, child: Text('항목4')),
        ),
      ),
    );

    // -50pt 이동은 터치 슬롭을 제외하면 액션 너비 절반(36pt)에 못 미치지만
    // 초당 2000pt로 빠르게 플링하면(속도가 임계값 500을 넘으면) 위치와
    // 무관하게 완전히 열려야 한다.
    await tester.fling(find.text('항목4'), const Offset(-50, 0), 2000);
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.ancestor(of: find.text('항목4'), matching: find.byType(Transform)).first,
    );
    expect(transform.transform.getTranslation().x, closeTo(-72, 0.5));
  });

  testWidgets('iOS: 다른 행을 열면 기존에 열려 있던 행은 닫힌다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(
        child: Column(
          children: [
            AppSwipeActions(
              itemKey: const ValueKey('row-swipe-a'),
              onDelete: () {},
              child: const SizedBox(height: 48, width: 300, child: Text('행A')),
            ),
            AppSwipeActions(
              itemKey: const ValueKey('row-swipe-b'),
              onDelete: () {},
              child: const SizedBox(height: 48, width: 300, child: Text('행B')),
            ),
          ],
        ),
      ),
    );

    await tester.drag(find.text('행A'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    final openTransformA = tester.widget<Transform>(
      find.ancestor(of: find.text('행A'), matching: find.byType(Transform)).first,
    );
    expect(openTransformA.transform.getTranslation().x, lessThan(0));

    await tester.drag(find.text('행B'), const Offset(-100, 0));
    await tester.pumpAndSettle();

    final closedTransformA = tester.widget<Transform>(
      find.ancestor(of: find.text('행A'), matching: find.byType(Transform)).first,
    );
    expect(closedTransformA.transform.getTranslation().x, 0);
  });
}
