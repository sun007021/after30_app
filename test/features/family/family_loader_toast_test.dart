import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/features/family/ui/widgets/family_loader.dart';
import 'package:after30/features/my/data/my_profile_service.dart';

import 'family_test_utils.dart';

class _FailingProfileService extends MyProfileService {
  @override
  Future<MyProfile> getMyProfile() async => throw Exception('network');
}

Future<void> _pump(WidgetTester tester, TargetPlatform platform, Widget home) async {
  useTallPhoneViewport(tester);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.build().copyWith(platform: platform), home: home),
  );
  await tester.pump();
}

/// §6 W8 7항 — SnackBar는 AppToast로, 로더는 iOS에서만 AppActivityIndicator.
void main() {
  testWidgets('iOS 로더는 CupertinoActivityIndicator', (tester) async {
    await _pump(tester, TargetPlatform.iOS, const Scaffold(body: FamilyLoader()));
    expect(find.byType(AppActivityIndicator), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Android 로더는 기존 CircularProgressIndicator 그대로', (tester) async {
    await _pump(tester, TargetPlatform.android, const Scaffold(body: FamilyLoader()));
    expect(find.byType(AppActivityIndicator), findsNothing);
    final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.strokeWidth, isNull); // 기존 기본값 그대로
    expect(indicator.color, isNull);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('프로필 조회 실패 안내는 AppToast($platform)', (tester) async {
      late BuildContext captured;
      await _pump(
        tester,
        platform,
        Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final ok = await tester.runAsync(
        () => ensurePhoneRegistered(captured, profileService: _FailingProfileService()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ok, isFalse);
      expect(find.text('내 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      if (platform == TargetPlatform.android) {
        expect(find.byType(SnackBar), findsOneWidget);
      } else {
        expect(find.byType(SnackBar), findsNothing);
      }
      // 토스트 타이머 정리.
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
