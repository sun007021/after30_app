import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  group('AppActivityIndicator', () {
    testWidgets('iOS에서는 CupertinoActivityIndicator를 쓴다', (tester) async {
      await pumpWithPlatform(tester, TargetPlatform.iOS, const Material(child: AppActivityIndicator()));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('Android에서는 CircularProgressIndicator를 쓴다', (tester) async {
      await pumpWithPlatform(tester, TargetPlatform.android, const Material(child: AppActivityIndicator()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppCheckmark', () {
    testWidgets('탭하면 반전된 값으로 onChanged가 호출된다', (tester) async {
      bool? result;
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        Material(child: AppCheckmark(checked: false, onChanged: (v) => result = v)),
      );

      await tester.tap(find.byType(AppCheckmark));
      await tester.pump();
      expect(result, isTrue);
    });
  });

  group('GlassSurface', () {
    testWidgets('고대비 모드에서는 불투명 배경(Material)으로 대체된다', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassSurface(child: SizedBox(width: 40, height: 40)),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Material), findsOneWidget);
    });

    testWidgets('일반 모드에서는 BackdropFilter로 블러를 적용한다', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GlassSurface(child: SizedBox(width: 40, height: 40)),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('iOS 기본 shape는 연속 곡률(RoundedSuperellipseBorder)이다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.iOS,
        const Material(child: GlassSurface(child: SizedBox(width: 40, height: 40))),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(GlassSurface), matching: find.byType(DecoratedBox)),
      );
      final decoration = decoratedBox.decoration as ShapeDecoration;
      expect(decoration.shape, isA<RoundedSuperellipseBorder>());
    });

    testWidgets('Android 기본 shape는 RoundedRectangleBorder이다', (tester) async {
      await pumpWithPlatform(
        tester,
        TargetPlatform.android,
        const Material(child: GlassSurface(child: SizedBox(width: 40, height: 40))),
      );
      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(GlassSurface), matching: find.byType(DecoratedBox)),
      );
      final decoration = decoratedBox.decoration as ShapeDecoration;
      expect(decoration.shape, isA<RoundedRectangleBorder>());
    });
  });

  group('AppTypography.clampTextScale', () {
    testWidgets('textScaler를 최대 1.3배로 제한한다', (tester) async {
      late double scaledFontSize;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppTypography.clampTextScale(
              child: Builder(
                builder: (context) {
                  scaledFontSize = MediaQuery.textScalerOf(context).scale(10);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      // 3.0배 대신 상한 1.3배까지만 적용되어야 한다.
      expect(scaledFontSize, 13.0);
    });
  });
}
