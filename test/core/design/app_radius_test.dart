import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  group('AppRadius.concentric', () {
    test('바깥 곡률에서 여백을 뺀 값을 반환한다', () {
      expect(AppRadius.concentric(22, 8), 14);
    });

    test('결과가 음수면 0으로 하한을 둔다', () {
      expect(AppRadius.concentric(8, 20), 0);
    });
  });

  group('AppRadius.shape', () {
    testWidgets('iOS에서는 RoundedSuperellipseBorder를 반환한다', (tester) async {
      late OutlinedBorder shape;
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        Builder(
          builder: (context) {
            shape = AppRadius.shape(context, AppRadius.md);
            return const SizedBox();
          },
        ),
      );
      expect(shape, isA<RoundedSuperellipseBorder>());
    });

    testWidgets('Android에서는 RoundedRectangleBorder를 반환한다', (tester) async {
      late OutlinedBorder shape;
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        Builder(
          builder: (context) {
            shape = AppRadius.shape(context, AppRadius.md);
            return const SizedBox();
          },
        ),
      );
      expect(shape, isA<RoundedRectangleBorder>());
    });
  });
}
