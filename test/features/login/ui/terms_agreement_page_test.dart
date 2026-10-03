import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';

import 'auth_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget iosApp() => buildAuthApp(
    const TermsAgreementPage(),
    TargetPlatform.iOS,
    routes: {'/signup': (_) => const Scaffold(body: Text('가입 화면'))},
  );

  List<bool> checks(WidgetTester tester) => tester
      .widgetList<AppCheckmark>(find.byType(AppCheckmark))
      .map((c) => c.checked)
      .toList();

  VoidCallback? ctaAction(WidgetTester tester) =>
      tester.widget<AppButton>(find.byType(AppButton)).onPressed;

  group('iOS', () {
    testWidgets('원형 체크 3개(전체 + 필수 2)와 비활성 CTA로 시작한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(iosApp());

      expect(find.byType(Checkbox), findsNothing);
      expect(checks(tester), [false, false, false]);
      expect(find.text('전체 동의'), findsOneWidget);
      expect(ctaAction(tester), isNull);
    });

    testWidgets('전체 동의가 모든 항목을 켜고 끈다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(iosApp());

      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(checks(tester), [true, true, true]);
      expect(ctaAction(tester), isNotNull);

      await tester.tap(find.text('전체 동의'));
      await tester.pump();
      expect(checks(tester), [false, false, false]);
    });

    testWidgets('필수 약관을 모두 동의해야 CTA가 열리고 하나 해제하면 전체 동의도 해제된다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(iosApp());

      await tester.tap(find.byType(AppCheckmark).at(1));
      await tester.pump();
      expect(ctaAction(tester), isNull);
      expect(checks(tester), [false, true, false]);

      await tester.tap(find.byType(AppCheckmark).at(2));
      await tester.pump();
      expect(ctaAction(tester), isNotNull);
      expect(checks(tester), [true, true, true]);

      await tester.tap(find.byType(AppCheckmark).at(1));
      await tester.pump();
      expect(checks(tester), [false, false, true]);
      expect(ctaAction(tester), isNull);
    });

    testWidgets('행을 탭해도 토글되고 CTA로 가입 화면에 이동한다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(iosApp());

      await tester.tap(find.text('(필수) 개인정보 수집 및 이용 동의'));
      await tester.tap(find.text('(필수) 서비스 이용약관'));
      await tester.pump();
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(find.text('가입 화면'), findsOneWidget);
    });

    testWidgets('셰브론을 누르면 약관 상세 시트가 열린다', (tester) async {
      useIphoneViewport(tester);
      await tester.pumpWidget(iosApp());

      await tester.tap(find.byIcon(CupertinoIcons.chevron_forward).first);
      await tester.pumpAndSettle();
      expect(find.text('전문 보기'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      // 시트를 열어도 동의 상태는 바뀌지 않는다.
      expect(checks(tester), [false, false, false]);

      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('전문 보기'), findsNothing);
    });
  });

  group('Android 기존 외형 유지', () {
    testWidgets('기존 SVG/이미지 체크 아이콘, 검은 구분선, 사각 버튼 값', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const TermsAgreementPage(), TargetPlatform.android));

      expect(find.byType(AppCheckmark), findsNothing);
      expect(find.byType(AppButton), findsNothing);
      expect(find.text('전체 약관동의'), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
      expect(tester.widget<Divider>(find.byType(Divider)).color, const Color(0xFF111111));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF235DFF));
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFD3DEFF),
      );
      expect(tester.getSize(find.byType(ElevatedButton)), const Size(120, 30));
    });

    testWidgets('필수 2개에 동의하면 버튼이 열리고 이미지 체크로 바뀐다', (tester) async {
      useAndroidViewport(tester);
      await tester.pumpWidget(buildAuthApp(const TermsAgreementPage(), TargetPlatform.android));

      await tester.tap(find.text('(필수)개인정보 수집 및 이용 동의'));
      await tester.tap(find.text('(필수)서비스 이용약관'));
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    });
  });
}
