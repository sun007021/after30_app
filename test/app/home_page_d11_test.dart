import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/home/ui/home.dart';

/// D11(2026-09-22): 로그인 직후 전화번호 등록 팝업을 더 이상 띄우지 않는다.
/// `checkPhoneRegistration` 파라미터는 하위 호환을 위해 `@Deprecated`로만
/// 남아있고 무시된다(plan §6 W10 6항).
void main() {
  testWidgets('checkPhoneRegistration: true를 넘겨도 전화번호 등록 팝업이 뜨지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        // ignore: deprecated_member_use_from_same_package
        home: const HomePage(checkPhoneRegistration: true),
      ),
    );

    // 네트워크(카카오/백엔드) 호출이 끝나기를 기다리지 않고, 초기 프레임 몇
    // 개만 확인한다 — D11 제거 대상 팝업은 initState에서 동기적으로 예약
    // 여부가 결정되므로 이걸로 충분하다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('전화번호'), findsNothing);
  });
}
