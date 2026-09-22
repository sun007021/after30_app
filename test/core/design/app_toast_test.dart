import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

import 'design_test_utils.dart';

void main() {
  testWidgets('iOS에서는 SnackBar 대신 글래스 배너로 메시지를 띄운다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(
        body: Builder(
          builder: (context) => AppButton(
            label: '토스트',
            onPressed: () => AppToast.show(context, '완료되었습니다.', type: AppToastType.success),
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트'));
    await tester.pump();
    expect(find.text('완료되었습니다.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // 배너는 페이드인(200ms) 후 2.5초 뒤 자동으로 페이드아웃(200ms)되며
    // 사라진다. 테스트 종료 시 "pending timer" 오류가 나지 않도록 전체
    // 애니메이션이 끝날 때까지 진행한다.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    expect(find.text('완료되었습니다.'), findsNothing);
  });

  testWidgets('배너를 탭하면 타이머를 기다리지 않고 바로 사라진다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(
        body: Builder(
          builder: (context) => AppButton(
            label: '토스트',
            onPressed: () => AppToast.show(context, '눌러서 닫기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트'));
    await tester.pump();
    expect(find.text('눌러서 닫기'), findsOneWidget);

    await tester.tap(find.text('눌러서 닫기'));
    // 탭 후 사라짐 애니메이션(200ms)만 기다리면 되고, 2.5초를 기다릴
    // 필요가 없어야 한다.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('눌러서 닫기'), findsNothing);
  });

  testWidgets('새 토스트가 뜨면 이전 배너와 타이머가 정리된다(중복 없음)', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              AppButton(label: '토스트1', onPressed: () => AppToast.show(context, '첫 번째')),
              AppButton(label: '토스트2', onPressed: () => AppToast.show(context, '두 번째')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트1'));
    await tester.pump();
    expect(find.text('첫 번째'), findsOneWidget);

    await tester.tap(find.text('토스트2'));
    await tester.pump();
    expect(find.text('첫 번째'), findsNothing);
    expect(find.text('두 번째'), findsOneWidget);

    // 두 번째 배너의 타이머만 남아 있어야 하며, pending timer 오류 없이
    // 정상적으로 끝나야 한다.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
  });

  testWidgets('iOS에서는 상단 안전영역 아래에 배너가 표시된다', (tester) async {
    late BuildContext capturedContext;
    await pumpWithPlatform(
      tester,
      TargetPlatform.iOS,
      Builder(
        // 실제 기기의 다른 MediaQueryData 값(크기 등)은 그대로 두고 top
        // 패딩만 안전영역 값으로 덮어써야 하므로, 통째로 새 MediaQueryData를
        // 만들지 않고 기존 값을 copyWith한다.
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 59)),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AppToast.show(capturedContext, '안전영역 테스트');
    await tester.pump();

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: find.text('안전영역 테스트'), matching: find.byType(Positioned)).first,
    );
    // 상단 안전영역(59pt) + 여백(8pt) 아래에 배치되어야 한다.
    expect(positioned.top, 67);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
  });

  testWidgets('Android에서는 기존 SnackBar로 메시지를 띄우고 배경색을 지정하지 않는다', (tester) async {
    await pumpWithPlatform(
      tester,
      TargetPlatform.android,
      Scaffold(
        body: Builder(
          builder: (context) => AppButton(
            label: '토스트',
            onPressed: () => AppToast.show(context, '완료되었습니다.', type: AppToastType.error),
          ),
        ),
      ),
    );

    await tester.tap(find.text('토스트'));
    await tester.pump();
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    // type과 무관하게 기존 25곳 호출부와 동일한 M3 기본 배경을 유지해야
    // 하므로 backgroundColor를 직접 지정하지 않는다.
    expect(snackBar.backgroundColor, isNull);
  });
}
