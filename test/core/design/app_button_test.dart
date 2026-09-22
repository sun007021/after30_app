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

  testWidgets('버튼 시맨틱스에 label과 button 플래그가 있다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      AppButton(label: '저장', onPressed: () {}),
    );
    final semantics = tester.getSemantics(find.byType(AppButton));
    expect(semantics.label, '저장');
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('로딩 중에는 시맨틱스 label에 로딩 중임을 표시한다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      AppButton(label: '저장', loading: true, onPressed: () {}),
    );
    final semantics = tester.getSemantics(find.byType(AppButton));
    expect(semantics.label, contains('로딩 중'));
  });

  testWidgets('눌린 채로 비활성화되었다가 다시 활성화되면 눌림 상태가 남지 않는다', (tester) async {
    final key = GlobalKey();
    Widget buildButton(VoidCallback? onPressed) => MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: AppButton(key: key, label: '토글', onPressed: onPressed),
    );

    await tester.pumpWidget(buildButton(() {}));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppButton)));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0.7);

    // 누른 채로 비활성화한다. GestureDetector의 onTapCancel도 null이 되어
    // 손을 떼도 눌림 해제 콜백이 자연스럽게 오지 않는다.
    await tester.pumpWidget(buildButton(null));
    await gesture.up();
    await tester.pump();

    // 다시 활성화했을 때 눌림 상태(0.7)가 남아있으면 안 된다.
    await tester.pumpWidget(buildButton(() {}));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1.0);
  });
}
