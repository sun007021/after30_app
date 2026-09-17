import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 CupertinoSwitch로 렌더링되고 토글 시 콜백을 호출한다', (tester) async {
    bool? value;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Material(child: AppSwitch(value: false, onChanged: (v) => value = v)),
    );

    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('Android에서는 기존 Switch로 렌더링된다', (tester) async {
    bool? value;
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Material(child: AppSwitch(value: false, onChanged: (v) => value = v)),
    );

    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, isTrue);
  });
}
