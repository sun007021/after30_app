import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';

/// 지정한 [platform]으로 [ThemeData.platform]이 설정된 [MaterialApp] 안에
/// [child]를 펌프한다. 디자인 시스템 컴포넌트는 `Theme.of(context).platform`
/// 으로 분기하므로, 실제 기기 없이도 iOS/Android 두 분기를 모두 테스트할 수
/// 있다.
Future<void> pumpWithPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: child,
    ),
  );
}
