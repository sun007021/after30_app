import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/ui/widgets/my_info_widgets.dart';

import 'my_test_utils.dart';

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder.first);
  return box.localToGlobal(Offset.zero) & box.size;
}

/// 토스트(2.5초 타이머)가 남지 않도록 끝에서 시간을 흘려보낸다.
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  // -----------------------------------------------------------------------
  // 내 정보 조회
  // -----------------------------------------------------------------------
  group('내 정보 조회 - Android는 base와 같은 값', () {
    testWidgets('배경, 카드, 행 글자 스타일과 SSO 표시', (tester) async {
      final service = FakeMyProfileService(
        profile: MyProfile(
          name: '홍길동',
          email: 'a@b.com',
          phoneNumber: '010-1234-5678',
          gender: '남',
          provider: 'kakao',
        ),
      );
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.android);

      expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, const Color(0xFFEBF0FF));
      expect(find.text('내 정보 조회'), findsOneWidget);
      expect(find.text('수정하기'), findsOneWidget);

      final card = tester.widgetList<MyInfoSectionCard>(find.byType(MyInfoSectionCard)).toList();
      expect(card.map((c) => c.title), ['기본 정보', '기타 정보']);
      final cardBox = tester.widget<Container>(
        find.descendant(of: find.byType(MyInfoSectionCard).first, matching: find.byType(Container)).first,
      );
      final decoration = cardBox.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(5));

      final valueText = tester.widget<Text>(find.text('a@b.com'));
      expect(valueText.style?.fontSize, 12);
      expect(valueText.style?.fontWeight, FontWeight.w400);
      expect(valueText.style?.color, Colors.black);
      expect(valueText.textAlign, TextAlign.right);

      expect(find.text('카카오톡'), findsOneWidget);
      expect(find.text('미동의'), findsOneWidget);
      expect(find.byType(AppGroupedSection), findsNothing);
      expect(find.text('미등록'), findsNothing);
    });

    testWidgets('번호가 없어도 Android는 기존처럼 "-"를 보여준다(미등록 행 없음)', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.android);
      expect(find.text('미등록'), findsNothing);
      expect(find.text('이메일'), findsOneWidget);
    });
  });

  group('내 정보 조회 - iOS', () {
    for (final entry in {'kakao': '카카오톡', 'email': '이메일', 'local': '이메일', 'apple': 'Apple'}.entries) {
      testWidgets('inset grouped 행과 provider 표시명: ${entry.key} -> ${entry.value}', (tester) async {
        final service = FakeMyProfileService(
          profile: MyProfile(
            name: '홍길동',
            email: 'a@b.com',
            phoneNumber: '010-1234-5678',
            gender: 'MALE',
            provider: entry.key,
          ),
        );
        await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.iOS);
        expect(find.text('기본 정보'), findsOneWidget);
        expect(find.text('기타 정보'), findsOneWidget);
        expect(find.text('010-1234-5678'), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('미등록'), findsNothing);
      });
    }

    testWidgets('이메일 가입자도 카카오 SDK 없이 정보가 보인다', (tester) async {
      final service = FakeMyProfileService(
        profile: MyProfile(name: '이메일유저', email: 'mail@x.com', provider: 'email', phoneNumber: '010-0000-0000'),
      );
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.iOS);
      expect(find.text('이메일유저'), findsOneWidget);
      expect(find.text('mail@x.com'), findsOneWidget);
    });

    testWidgets('번호 미등록이면 "미등록" 행이 시트를 열고, 등록하면 번호가 보인다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.iOS);
      expect(find.text('미등록'), findsOneWidget);

      await tester.tap(find.text('미등록'));
      await tester.pumpAndSettle();
      expect(find.text('전화번호를 등록해 주세요'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '01012345678');
      await tester.pump();
      await tester.tap(find.text('등록하기'));
      await tester.pumpAndSettle();

      expect(service.phoneUpdateCalls, 1);
      expect(find.text('미등록'), findsNothing);
      expect(find.text('010-1234-5678'), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('미등록 행을 연속으로 눌러도 시트는 하나만 열린다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.iOS);

      final tile = tester.widget<AppListTile>(find.widgetWithText(AppListTile, '전화번호'));
      tile.onTap!();
      await tester.pump(const Duration(milliseconds: 150));
      tile.onTap!();
      await tester.pumpAndSettle();
      expect(find.text('전화번호를 등록해 주세요'), findsOneWidget);
    });

    testWidgets('조회 실패하면 오류 행이 보이고 탭하면 다시 시도한다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', phoneNumber: '010-1234-5678', provider: 'email'))
        ..failGet = true;
      await pumpScreen(tester, buildInfoPage(service), platform: TargetPlatform.iOS);
      expect(find.text('내 정보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('미등록'), findsNothing, reason: '실패 상태에서 미등록으로 오인시키면 안 된다');

      service.failGet = false;
      await tester.tap(find.text('내 정보를 불러오지 못했어요'));
      await tester.pump();
      await tester.pump();
      expect(find.text('내 정보를 불러오지 못했어요'), findsNothing);
      expect(find.text('010-1234-5678'), findsOneWidget);
    });

    testWidgets('마이 탭이 다시 활성화되면 다시 불러와 "미등록"이 사라진다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpShellWith(tester, buildInfoPage(service), platform: TargetPlatform.iOS);
      expect(find.text('미등록'), findsOneWidget);

      final shell = tester.state<AppShellState>(find.byType(AppShell));
      shell.switchTab(AppShellTab.family);
      await tester.pump();
      service.profile = MyProfile(name: '홍길동', provider: 'email', phoneNumber: '010-9999-8888');
      shell.switchTab(AppShellTab.my);
      await tester.pump();
      await tester.pump();

      expect(find.text('미등록'), findsNothing);
      expect(find.text('010-9999-8888'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  // 내 정보 수정
  // -----------------------------------------------------------------------
  group('내 정보 수정 - Android는 base와 같은 값', () {
    testWidgets('헤더/필드/성별 라디오 스타일', (tester) async {
      final profile = FakeMyProfileService();
      await pumpEditPage(tester, platform: TargetPlatform.android, profile: profile);

      expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, const Color(0xFFEBF0FF));
      expect(find.text('수정완료'), findsOneWidget);
      expect(find.byType(MyInfoGenderSelector), findsOneWidget);
      expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsNothing);
      expect(find.byType(AppTextField), findsNothing);
      expect(find.text('번호확인'), findsOneWidget);

      // 번호확인 버튼: 흰 배경 + #CAD8FF 테두리 + 반지름 5.
      final checkBox = tester.widget<Container>(
        find.ancestor(of: find.text('번호확인'), matching: find.byType(Container)).first,
      );
      final decoration = checkBox.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(5));
      expect((decoration.border! as Border).top.color, const Color(0xFFCAD8FF));
      final label = tester.widget<Text>(find.text('번호확인'));
      expect(label.style?.fontSize, 12);
      expect(label.style?.color, const Color(0xFF235DFF));

      // 이메일/SSO는 읽기 전용.
      expect(find.text('이메일'), findsOneWidget);
    });

    testWidgets('저장 성공 시 결과를 pop한다', (tester) async {
      final profile = FakeMyProfileService();
      final result = ValueNotifier<Object?>(null);
      await pumpEditPage(tester, platform: TargetPlatform.android, profile: profile, result: result);

      await tester.tap(find.text('수정완료'));
      await tester.pumpAndSettle();
      expect(profile.updateCalls, 1);
      expect(result.value, isA<MyProfile>());
    });
  });

  group('내 정보 수정 - iOS', () {
    testWidgets('컴포넌트 구성: AppTextField, 숫자패드+완료 바, 성별 세그먼트, 읽기 전용 행, 내비게이션 바 완료', (tester) async {
      final profile = FakeMyProfileService();
      await pumpEditPage(tester, platform: TargetPlatform.iOS, profile: profile);

      expect(find.byType(AppTextField), findsNWidgets(2));
      final fields = tester.widgetList<AppTextField>(find.byType(AppTextField)).toList();
      final phone = fields.firstWhere((f) => f.keyboardType == TextInputType.phone);
      expect(phone.showKeyboardDoneBar, isTrue);
      expect(phone.inputFormatters!.whereType<PhoneNumberFormatter>(), hasLength(1));
      expect(phone.autofillHints, contains(AutofillHints.telephoneNumber));
      final name = fields.firstWhere((f) => f.keyboardType != TextInputType.phone);
      expect(name.autocorrect, isFalse);
      expect(name.enableSuggestions, isFalse);

      expect(find.byType(AppSegmentedControl<String>), findsOneWidget);
      expect(find.text('번호확인'), findsOneWidget);
      final button = tester.widget<AppButton>(find.widgetWithText(AppButton, '번호확인'));
      expect(button.variant, AppButtonVariant.tinted);

      // 이메일/SSO는 편집 불가 행(텍스트필드 아님).
      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.byType(MyInfoNavAction), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
      expect(find.text('수정완료'), findsNothing);
    });

    testWidgets('전화번호 입력은 자동 하이픈이 붙는다', (tester) async {
      final profile = FakeMyProfileService();
      await pumpEditPage(
        tester,
        platform: TargetPlatform.iOS,
        profile: profile,
        args: {'name': '홍', 'phoneNumber': '', 'email': 'a@b.com', 'gender': '여', 'provider': 'email'},
      );
      final phoneField = find.descendant(
        of: find.byWidgetPredicate((w) => w is AppTextField && w.keyboardType == TextInputType.phone),
        matching: find.byType(EditableText),
      );
      await tester.enterText(phoneField, '01099998888');
      await tester.pump();
      expect(find.text('010-9999-8888'), findsOneWidget);
    });

    testWidgets('저장 중복 탭: 500ms 지연 중 150ms 간격으로 두 번 눌러도 1회', (tester) async {
      final profile = FakeMyProfileService(updateDelay: const Duration(milliseconds: 500));
      final result = ValueNotifier<Object?>(null);
      await pumpEditPage(tester, platform: TargetPlatform.iOS, profile: profile, result: result);

      await tester.tap(find.byType(MyInfoNavAction));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(MyInfoNavAction), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(MyInfoNavAction), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(profile.updateCalls, 1);
      expect(result.value, isA<MyProfile>());
    });

    testWidgets('저장 실패 후에는 플래그가 풀려 재시도할 수 있다', (tester) async {
      final profile = FakeMyProfileService(updateDelay: const Duration(milliseconds: 500))
        ..updateErrors.addAll([Exception('boom'), null]);
      final result = ValueNotifier<Object?>(null);
      await pumpEditPage(tester, platform: TargetPlatform.iOS, profile: profile, result: result);

      await tester.tap(find.byType(MyInfoNavAction));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.byType(MyInfoNavAction), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(profile.updateCalls, 1);
      expect(result.value, isNull, reason: '실패하면 화면에 남는다');
      expect(find.text('정보 수정에 실패했습니다. 다시 시도해주세요.'), findsOneWidget);
      await _drainToasts(tester);

      await tester.tap(find.byType(MyInfoNavAction));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(profile.updateCalls, 2);
      expect(result.value, isA<MyProfile>());
    });

    testWidgets('번호가 바뀌면 번호확인 전에는 저장되지 않는다', (tester) async {
      final profile = FakeMyProfileService();
      await pumpEditPage(tester, platform: TargetPlatform.iOS, profile: profile);
      final phoneField = find.descendant(
        of: find.byWidgetPredicate((w) => w is AppTextField && w.keyboardType == TextInputType.phone),
        matching: find.byType(EditableText),
      );
      await tester.enterText(phoneField, '01099998888');
      await tester.pump();
      await tester.tap(find.byType(MyInfoNavAction));
      await tester.pump();
      expect(profile.updateCalls, 0);
      expect(find.text('전화번호 확인을 먼저 진행해주세요.'), findsOneWidget);
      await _drainToasts(tester);

      await tester.tap(find.text('번호확인'));
      await tester.pump();
      await tester.pump();
      expect(find.text('사용 가능한 번호입니다.'), findsOneWidget);
      await tester.tap(find.byType(MyInfoNavAction));
      await tester.pumpAndSettle();
      expect(profile.updateCalls, 1);
    });

    testWidgets('키보드가 올라와도 저장 버튼과 마지막 필드에 접근할 수 있다(실제 세이프에어리어)', (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
      addTearDown(tester.view.reset);

      final profile = FakeMyProfileService();
      await pumpEditPage(tester, platform: TargetPlatform.iOS, profile: profile);

      // 키보드 336pt가 올라온 상태(이때 하단 안전 영역은 0으로 보고된다).
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      const keyboardTop = 2622 / 3 - 336;
      // 저장 버튼(내비게이션 바)은 화면 위쪽이라 키보드에 가리지 않는다.
      expect(_rect(tester, find.byType(MyInfoNavAction)).bottom, lessThan(keyboardTop));
      // 마지막 필드(연동된 SSO 행)를 스크롤해 키보드 위로 올릴 수 있다.
      await tester.scrollUntilVisible(find.text('연동된 SSO'), 100, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(_rect(tester, find.text('연동된 SSO')).bottom, lessThanOrEqualTo(keyboardTop + 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('iPhone SE(750x1334 dpr2) 글자 1.5배 오버플로 없음', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

      testWidgets('$label: 내 정보', (tester) async {
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        final service = FakeMyProfileService(
          profile: MyProfile(
            name: '아주아주아주긴이름의사용자입니다',
            email: 'very.long.email.address.for.overflow.check@example-domain.com',
            phoneNumber: '010-1234-5678',
            gender: '남',
            provider: 'email',
          ),
        );
        await pumpScreen(tester, buildInfoPage(service), platform: platform, textScale: 1.5, tallView: false);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: 내 정보 수정', (tester) async {
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: themeFor(platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(body: SizedBox()),
          ),
        );
        // 인자 있는 라우트로 진입.
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        nav.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: {
                'name': '홍길동',
                'phoneNumber': '010-1234-5678',
                'email': 'very.long.email.address.for.overflow.check@example-domain.com',
                'gender': '남',
                'provider': 'email',
              },
            ),
            builder: (_) => buildEditPage(FakeMyProfileService()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
