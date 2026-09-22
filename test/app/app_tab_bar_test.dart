import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'app_shell_test_utils.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS 탭바는 GlassSurface 위에 5개의 텍스트 라벨을 보여준다', (tester) async {
    await pumpAppShell(tester, platform: TargetPlatform.iOS);

    expect(find.byType(GlassSurface), findsOneWidget);
    for (final label in const ['알람', '가족', '홈', '기록', '마이']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Android 탭바는 기존 navicon SVG 5개를 그대로 렌더링한다', (tester) async {
    await pumpAppShell(tester, platform: TargetPlatform.android);

    expect(find.byType(GlassSurface), findsNothing);

    for (final prefix in const ['alarm', 'fam', 'home', 'his', 'my']) {
      final expected = prefix == 'home' ? 'active' : 'deactive';
      // 기본 진입 탭은 홈이므로 홈만 active, 나머지는 deactive 에셋을 쓴다.
      final matches = find.byWidgetPredicate((widget) {
        if (widget is! SvgPicture) return false;
        final loader = widget.bytesLoader;
        return loader is SvgAssetLoader &&
            loader.assetName == 'assets/images/navicon/${prefix}_$expected.svg';
      });
      expect(matches, findsOneWidget, reason: '$prefix 탭 아이콘을 찾지 못했습니다');
    }
  });
}
