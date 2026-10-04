import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('그래버와 내용을 표시하고 값을 반환한다', (tester) async {
    String? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        builder: (context) => AppButton(
          label: '시트 열기',
          onPressed: () async {
            result = await showAppSheet<String>(
              context: context,
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).pop('done'),
                child: const Text('닫기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('시트 열기'));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('닫힘 중 탭 차단 ($platform)', () {
      var behindTaps = 0;

      Future<void> openSheet(WidgetTester tester) async {
        behindTaps = 0;
        await pumpWithPlatform(
          tester,
          platform,
          Scaffold(
            body: Column(
              children: [
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAppSheet<void>(
                      context: context,
                      builder: (ctx) => TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('닫기'),
                      ),
                    ),
                    child: const Text('시트 열기'),
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () => behindTaps++, child: const Text('뒤 버튼')),
              ],
            ),
          ),
        );
        await tester.tap(find.text('시트 열기'));
        await tester.pumpAndSettle();
        expect(find.text('닫기'), findsOneWidget);
      }

      testWidgets('닫히는 중에는 뒤 화면 버튼이 눌리지 않고, 닫힌 뒤에는 눌린다', (tester) async {
        await openSheet(tester);
        final behind = tester.getCenter(find.text('뒤 버튼', skipOffstage: false));

        await tester.tap(find.text('닫기'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(behind);
        expect(behindTaps, 0);

        await tester.pumpAndSettle();
        expect(find.text('닫기'), findsNothing);
        await tester.tap(find.text('뒤 버튼'));
        expect(behindTaps, 1);
      });

      testWidgets('시트 안 LocalHistoryEntry가 pop을 소비하면 차단 레이어를 넣지 않는다', (tester) async {
        await openSheet(tester);
        final sheetContext = tester.element(find.text('닫기'));
        var removed = false;
        ModalRoute.of(sheetContext)!.addLocalHistoryEntry(LocalHistoryEntry(onRemove: () => removed = true));
        Navigator.of(sheetContext).pop(); // 로컬 히스토리만 빠지고 시트는 열린 채
        await tester.pump(const Duration(milliseconds: 500));
        expect(removed, isTrue);
        expect(find.text('닫기'), findsOneWidget);

        // 레이어가 남았다면 시트 버튼이 눌리지 않아 닫히지 않는다.
        // (레이어가 남으면 settle되지 않으므로 고정 시간만 진행한다.)
        await tester.tap(find.text('닫기'), warnIfMissed: false);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('닫기'), findsNothing);
        await tester.tap(find.text('뒤 버튼'));
        expect(behindTaps, 1);
      }, timeout: const Timeout(Duration(seconds: 30)));

      testWidgets('배리어 탭으로 닫히고, 닫히는 중 탭은 차단된다', (tester) async {
        await openSheet(tester);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(tester.getCenter(find.text('뒤 버튼', skipOffstage: false)));
        expect(behindTaps, 0);

        await tester.pumpAndSettle();
        expect(find.text('닫기'), findsNothing);
      });
    });
  }

  testWidgets('Android에서도 그래버와 내용을 표시하고 값을 반환한다', (tester) async {
    String? result;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Builder(
        builder: (context) => AppButton(
          label: '시트 열기',
          onPressed: () async {
            result = await showAppSheet<String>(
              context: context,
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).pop('done'),
                child: const Text('닫기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('시트 열기'));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });
}
