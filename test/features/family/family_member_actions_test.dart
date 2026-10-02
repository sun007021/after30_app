import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/family/ui/family_group_manage_page.dart';

import 'family_test_utils.dart';

Future<FakeFamilyService> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  int currentUserId = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  useTallPhoneViewport(tester);
  final service = FakeFamilyService(
    groups: [fakeGroup()],
    members: [fakeMember(), fakeMember(userId: 2, name: '엄마', role: 'MEMBER')],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build().copyWith(platform: platform),
      home: FamilyGroupManagePage(
        groupId: 1,
        groupName: '우리 가족',
        familyService: service,
        resolveCurrentUserId: (_) async => currentUserId,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// §6 W8 4항 — 멤버 행 동작(더보기/길게 누르기 → 액션 시트)과 파괴적 확인.
void main() {
  group('iOS', () {
    testWidgets('더보기 → 액션 시트: 멤버 제거는 파괴적, 가족장 위임은 일반', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      final actions = tester
          .widgetList<CupertinoActionSheetAction>(find.byType(CupertinoActionSheetAction))
          .toList();
      final remove = actions.firstWhere((a) => (a.child as Text).data == '멤버 제거');
      final transfer = actions.firstWhere((a) => (a.child as Text).data == '가족장 위임');
      expect(remove.isDestructiveAction, isTrue);
      expect(transfer.isDestructiveAction, isFalse);
    });

    testWidgets('길게 누르면 같은 액션 시트가 열린다', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      await tester.longPress(find.text('엄마'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
    });

    testWidgets('멤버 제거: 파괴적 확인 알럿을 거쳐 제거한다', (tester) async {
      final service = await _pump(tester, TargetPlatform.iOS);

      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '멤버 제거'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final confirm = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .firstWhere((a) => (a.child as Text).data == '제거');
      expect(confirm.isDestructiveAction, isTrue);

      await tester.tap(find.text('제거'));
      await tester.pumpAndSettle();
      expect(service.removedUserIds, [2]);
    });

    testWidgets('가족장 위임: 확인 후 위임한다', (tester) async {
      final service = await _pump(tester, TargetPlatform.iOS);

      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '가족장 위임'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('위임'));
      await tester.pumpAndSettle();
      expect(service.transferredToUserIds, [2]);
    });

    testWidgets('가족장이 아니면 더보기가 없다', (tester) async {
      await _pump(tester, TargetPlatform.iOS, currentUserId: 2);
      expect(find.byIcon(CupertinoIcons.ellipsis), findsNothing);
    });

    testWidgets('탈퇴 확인은 파괴적 알럿이다', (tester) async {
      // 멤버(가족장 아님)로 접속해 탈퇴 가능 상태를 만든다.
      final service = await _pump(tester, TargetPlatform.iOS, currentUserId: 2);

      await tester.tap(find.text('가족 그룹 탈퇴하기'));
      await tester.pumpAndSettle();
      final confirm = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .firstWhere((a) => (a.child as Text).data == '탈퇴');
      expect(confirm.isDestructiveAction, isTrue);
      expect(service.leftGroupIds, isEmpty);
    });
  });

  group('Android', () {
    testWidgets('더보기는 기존 팝업 메뉴이고 액션 시트가 아니다', (tester) async {
      await _pump(tester, TargetPlatform.android);

      await tester.tap(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 4).first);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('가족장 위임'), findsOneWidget);
      expect(find.text('멤버 제거'), findsOneWidget);
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
    });

    testWidgets('멤버 제거 확인은 기존 브랜드 색 버튼(파괴적 빨강 아님)이다', (tester) async {
      final service = await _pump(tester, TargetPlatform.android);

      await tester.tap(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 4).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('멤버 제거'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      final confirm = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '제거'));
      expect(
        confirm.style!.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.primary,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '제거'));
      await tester.pumpAndSettle();
      expect(service.removedUserIds, [2]);
    });

    testWidgets('길게 눌러도 액션 시트가 열리지 않는다', (tester) async {
      await _pump(tester, TargetPlatform.android);
      await tester.longPress(find.text('엄마'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
    });
  });
}
