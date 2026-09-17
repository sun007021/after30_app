import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 리플 위젯(ElevatedButton) 없이 GestureDetector로 렌더링된다', (tester) async {
    var tapped = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      AppButton(label: '확인', onPressed: () => tapped = true),
    );

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('확인'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('Android에서는 기존 ElevatedButton 계열로 렌더링된다', (tester) async {
    var tapped = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      AppButton(label: '확인', onPressed: () => tapped = true),
    );

    expect(find.byType(ElevatedButton), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('loading 상태에서는 인디케이터를 보여주고 탭이 막힌다', (tester) async {
    var tapped = false;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      AppButton(label: '저장', loading: true, onPressed: () => tapped = true),
    );

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('저장'), findsNothing);

    // CupertinoActivityIndicator는 계속 회전하므로 pumpAndSettle 대신
    // 한 프레임만 진행한다.
    await tester.tap(find.byType(CupertinoActivityIndicator));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('onPressed가 null이면 비활성 상태로 탭이 막힌다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      const AppButton(label: '비활성', onPressed: null),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
