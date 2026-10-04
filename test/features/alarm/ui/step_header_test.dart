import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/features/family/ui/family_invite_group_select_page.dart';

import '../../family/family_test_utils.dart';

// W5가 바꾼 StepHeader(iOS Expanded 연결선)는 W8 가족 초대 화면(라벨 없는
// 변형)에서도 쓰이므로, 두 변형이 모두 정상 렌더링되는지 확인한다.
void main() {
  Future<void> pump(WidgetTester tester, TargetPlatform platform, Widget home,
      {double width = 390, double textScale = 1.0}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('라벨 없는 StepHeader가 $platform ${width.toInt()}pt에서 넘치지 않는다', (tester) async {
        await pump(
          tester,
          platform,
          const Scaffold(
            body: StepHeader(currentStep: 2, step1Label: '', step2Label: '', step3Label: ''),
          ),
          width: width,
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });
    }
  }

  testWidgets('라벨이 있는 StepHeader(iOS)는 좁은 화면에서도 넘치지 않는다', (tester) async {
    await pump(
      tester,
      TargetPlatform.iOS,
      const Scaffold(body: StepHeader(currentStep: 1)),
      width: 320,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('약 정보 입력'), findsOneWidget);
  });

  testWidgets('Android: 활성 원 색은 기존 값(0xFF235DFF)을 유지한다', (tester) async {
    await pump(tester, TargetPlatform.android, const Scaffold(body: StepHeader(currentStep: 1)),
        width: 600);
    final circle = tester.widget<Container>(
      find.ancestor(of: find.text('1'), matching: find.byType(Container)).first,
    );
    expect((circle.decoration as BoxDecoration).color, const Color(0xFF235DFF));
  });

  testWidgets('W8 가족 초대 1단계 화면이 iOS에서 StepHeader와 함께 렌더링된다', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
        home: const FamilyInviteGroupSelectPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(StepHeader), findsOneWidget);
    expect(find.text('1. 그룹 선택'), findsOneWidget);
  });
}
