import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:after30/features/home/ui/widgets/add_medicine_tile.dart';

import '../../../core/design/design_test_utils.dart';

void main() {
  testWidgets('Android에서는 기존 곡률(12)을 그대로 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Scaffold(body: AddMedicineTile(onAdd: () {})),
    );

    final border = tester.widget<DottedBorder>(find.byType(DottedBorder));
    expect(border.radius.x, 12);
  });

  testWidgets('iOS에서는 곡률 토큰(AppRadius.md=16)을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(body: AddMedicineTile(onAdd: () {})),
    );

    final border = tester.widget<DottedBorder>(find.byType(DottedBorder));
    expect(border.radius.x, 16);
  });
}
