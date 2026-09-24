import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/home/ui/widgets/empty_medicine_section.dart';

import '../../../core/design/design_test_utils.dart';

void main() {
  testWidgets('Android에서는 기존 ElevatedButton 외형을 그대로 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Scaffold(body: EmptyMedicineSection(onAdd: () {})),
    );

    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    expect(find.text('약 등록하기'), findsOneWidget);
  });

  testWidgets('iOS에서는 토큰 기반 AppButton(캡슐)을 쓴다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(body: EmptyMedicineSection(onAdd: () {})),
    );

    expect(find.byType(AppButton), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('약 등록하기'), findsOneWidget);
  });
}
