// 앱 스모크 테스트.
//
// 기존 템플릿 카운터 테스트는 실제 앱 화면과 무관했고 항상 실패했다.
// `MyApp()`을 직접 펌프하면 Firebase/Kakao 초기화, 네트워크, 로컬 저장소
// 등 테스트 환경에서 목(mock) 처리되지 않은 의존성이 얽혀 있어 신뢰할 수
// 없으므로, 대신 W2가 소유한 디자인 시스템이 정상적으로 동작하는지를
// iOS/Android 두 플랫폼에서 확인한다: 앱 테마가 만들어지고, 디버그 전용
// 디자인 갤러리가 두 플랫폼 모두에서 예외 없이 렌더링되는 것을 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:after30/core/design/app_theme.dart';
import 'package:after30/core/design/gallery/design_gallery_page.dart';

void main() {
  test('AppTheme.build()는 예외 없이 ThemeData를 생성한다', () {
    final theme = AppTheme.build();
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('디자인 갤러리는 iOS 플랫폼에서 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
        home: const DesignGalleryPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(DesignGalleryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('디자인 갤러리는 Android 플랫폼에서 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build().copyWith(platform: TargetPlatform.android),
        home: const DesignGalleryPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(DesignGalleryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
