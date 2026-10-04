import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/features/home/ui/widgets/medication_dose_tile.dart';
import 'package:after30/utils/responsive.dart';

import '../../../core/design/design_test_utils.dart';
import '../home_test_utils.dart';

void main() {
  Widget buildTile({bool isProcessing = false}) {
    final medication = fakeMedication(time: '09:00', date: DateTime.now());
    return Scaffold(
      body: MedicationDoseTile(
        medication: medication,
        selectedDate: medication.date,
        doseKey: 'k',
        isProcessing: isProcessing,
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

  testWidgets('Android 처리 중 인디케이터는 기존 값(반응형 16 박스, 두께 2, 흰색)이다', (tester) async {
    await pumpWithPlatform(tester, TargetPlatform.android, buildTile(isProcessing: true));

    final finder = find.byType(CircularProgressIndicator);
    final indicator = tester.widget<CircularProgressIndicator>(finder);
    expect(indicator.strokeWidth, 2);
    expect(indicator.color, Colors.white);
    final expected = Responsive.responsiveIconSize(tester.element(finder), 16);
    expect(tester.getSize(finder), Size(expected, expected));
  });

  testWidgets('iOS 처리 중에는 CupertinoActivityIndicator를 쓴다', (tester) async {
    await pumpWithPlatform(tester, TargetPlatform.iOS, buildTile(isProcessing: true));

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
