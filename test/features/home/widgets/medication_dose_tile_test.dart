import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';

import '../../../core/design/design_test_utils.dart';
import '../home_test_utils.dart';

void main() {
  Widget buildTile() {
    final medication = fakeMedication(time: '09:00', date: DateTime.now());
    return Scaffold(
      body: MedicationDoseTile(
        medication: medication,
        selectedDate: medication.date,
        doseKey: 'k',
        onMarkCompleted: (_) async => true,
        onMarkUncompleted: (_) async {},
      ),
    );
  }

  testWidgets('Android에서는 기존 사각 곡률(16)과 테두리를 그대로 쓴다(외형 변경 없음)', (tester) async {
    await pumpWithPlatform(tester, TargetPlatform.android, buildTile());

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(MedicationDoseTile), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect((decoration.borderRadius as BorderRadius?)?.topLeft.x, 16);
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('iOS에서는 토큰 곡률(AppRadius.lg, 연속 곡률)과 그림자를 쓴다', (tester) async {
    await pumpWithPlatform(tester, TargetPlatform.iOS, buildTile());

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(MedicationDoseTile), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as ShapeDecoration;
    expect(decoration.shape, isA<RoundedSuperellipseBorder>());
    expect(decoration.shadows, isNotEmpty);
  });
}
