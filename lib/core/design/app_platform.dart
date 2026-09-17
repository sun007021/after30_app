import 'package:flutter/material.dart';

/// 플랫폼 분기의 단일 진입점.
///
/// `dart:io`의 `Platform`을 직접 쓰면 위젯 테스트에서 플랫폼을 주입할 수
/// 없으므로, 항상 [Theme.of]가 제공하는 [ThemeData.platform]을 기준으로
/// 판단한다. 테스트에서는 `ThemeData(platform: TargetPlatform.iOS)`처럼
/// 테마를 주입해 분기를 검증한다.
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}
