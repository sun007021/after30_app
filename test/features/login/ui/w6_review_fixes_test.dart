import 'dart:ui' show SemanticsFlag;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsData;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/login/ui/email_login_page.dart';
import 'package:after30/features/login/ui/signup_intro.dart';
import 'package:after30/features/login/ui/signup_page.dart';
import 'package:after30/features/login/ui/terms_agreement_page.dart';

import 'auth_test_support.dart';

/// PR #37 리뷰 반영(M1, m1~m4) 회귀 테스트.
class _Launcher extends UrlLauncherPlatform {
  _Launcher({this.result = true, this.throwOnLaunch = false});
  final bool result;
  final bool throwOnLaunch;
  int launches = 0;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches++;
    if (throwOnLaunch) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return result;
  }
}

/// 첫 화면의 OPEN 버튼으로 [page]를 push한다(뒤로 가기로 dispose를 일으키기 위함).
Widget _pushApp(Widget page) => MaterialApp(
  theme: AppTheme.build().copyWith(platform: TargetPlatform.iOS),
  home: Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('OPEN'),
        ),
      ),
    ),
  ),
);

/// iPhone SE(3세대): 750x1334, dpr 2, 하단 세이프에어리어 없음.
void _useSeViewport(WidgetTester t) {
  t.view.physicalSize = const Size(750, 1334);
  t.view.devicePixelRatio = 2;
  t.view.padding = const FakeViewPadding(top: 40);
  t.view.viewPadding = const FakeViewPadding(top: 40);
  addTearDown(t.view.reset);
}

/// 키체인 저장 제안(`finishAutofillContext(true)`) 호출만 모은다.
List<MethodCall> _autofillCommits(WidgetTester t) => t.testTextInput.log
    .where((c) => c.method == 'TextInput.finishAutofillContext' && c.arguments == true)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpAuthStorage);
  tearDown(tearDownAuthStorage);

  group('M1 키체인 저장 제안은 성공 시에만', () {
    testWidgets('로그인 실패 후 뒤로 가도 저장 제안이 나가지 않는다', (t) async {
      useIphoneViewport(t);
      final backend = FakeBackend(delay: const Duration(milliseconds: 50))..install();
      addTearDown(backend.uninstall);
      await t.pumpWidget(_pushApp(const EmailLoginPage()));
      await t.tap(find.text('OPEN'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(CupertinoTextField).first, 'a@b.com');
      await t.enterText(find.byType(CupertinoTextField).last, 'wrong-pw');
      await t.pump();
      await t.tap(find.byType(AppButton));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호가 일치하지 않습니다.'), findsOneWidget);
      t.testTextInput.log.clear();

      await t.tap(find.byIcon(CupertinoIcons.back));
      await t.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
      expect(_autofillCommits(t), isEmpty);
    });

    testWidgets('회원가입을 제출하지 않고 뒤로 가도 저장 제안이 나가지 않는다', (t) async {
      useIphoneViewport(t);
      await t.pumpWidget(_pushApp(const SignupPage()));
      await t.tap(find.text('OPEN'));
      await t.pumpAndSettle();
      final f = find.byType(CupertinoTextField);
      await t.enterText(f.at(0), '홍길동');
      await t.enterText(f.at(1), 'a@b.com');
      await t.enterText(f.at(2), 'Strong-Pass-123');
      await t.enterText(f.at(3), 'Strong-Pass-123');
      await t.pump();
      t.testTextInput.log.clear();

      await t.tap(find.byIcon(CupertinoIcons.back));
      await t.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
      expect(_autofillCommits(t), isEmpty);
    });

    testWidgets('회원가입 이메일은 username 힌트를 함께 쓰고 자동 수정을 끈다', (t) async {
      useIphoneViewport(t);
      await t.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));
      final email = t.widget<CupertinoTextField>(find.byType(CupertinoTextField).at(1));
      expect(email.autofillHints, containsAll([AutofillHints.email, AutofillHints.username]));
      expect(email.autocorrect, isFalse);
      expect(email.enableSuggestions, isFalse);
    });
  });

  group('m1 키보드가 올라온 상태에서 불일치 문구가 CTA 위에 보인다', () {
    for (final dev in ['16e', 'SE']) {
      testWidgets(dev, (t) async {
        if (dev == '16e') {
          useIphoneViewport(t);
        } else {
          _useSeViewport(t);
        }
        await t.pumpWidget(buildAuthApp(const SignupPage(), TargetPlatform.iOS));
        final f = find.byType(CupertinoTextField);
        await t.tap(f.at(2));
        await t.pump();
        t.view.viewInsets = FakeViewPadding(bottom: dev == '16e' ? 336 * 3.0 : 260 * 2.0);
        await t.pumpAndSettle();
        await t.enterText(f.at(2), 'password1');
        await t.tap(f.at(3), warnIfMissed: false);
        await t.pump();
        await t.enterText(f.at(3), 'password2');
        await t.pumpAndSettle();

        final ctaTop = t.getTopLeft(find.byType(AppButton)).dy;
        expect(t.getBottomLeft(find.text('비밀번호가 일치하지 않습니다')).dy, lessThanOrEqualTo(ctaTop));
      });
    }
  });

  testWidgets('m2 가입 안내 카카오 버튼은 SE 폭, 글자 2배에서도 넘치지 않는다', (t) async {
    _useSeViewport(t);
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(buildAuthApp(const SignupIntroPage(), TargetPlatform.iOS));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  group('m3 약관 행 VoiceOver 체크 상태', () {
    testWidgets('개별 약관과 전체 동의 행이 checked 상태를 알린다', (t) async {
      useIphoneViewport(t);
      final handle = t.ensureSemantics();
      await t.pumpWidget(buildAuthApp(const TermsAgreementPage(), TargetPlatform.iOS));

      SemanticsData data(String text) => t.getSemantics(find.text(text)).getSemanticsData();
      // ignore: deprecated_member_use
      bool checked(String text) => data(text).hasFlag(SemanticsFlag.isChecked);
      // ignore: deprecated_member_use
      expect(data('(필수) 서비스 이용약관').hasFlag(SemanticsFlag.hasCheckedState), isTrue);
      // ignore: deprecated_member_use
      expect(data('전체 동의').hasFlag(SemanticsFlag.hasCheckedState), isTrue);
      expect(checked('(필수) 서비스 이용약관'), isFalse);

      await t.tap(find.text('전체 동의'));
      await t.pump();
      expect(checked('(필수) 서비스 이용약관'), isTrue);
      expect(checked('전체 동의'), isTrue);
      handle.dispose();
    });
  });

  group('m4 약관 전문 링크 실패 처리', () {
    Future<void> openFullText(WidgetTester t) async {
      await t.pumpWidget(buildAuthApp(const TermsAgreementPage(), TargetPlatform.iOS));
      await t.tap(find.byIcon(CupertinoIcons.chevron_forward).first);
      await t.pumpAndSettle();
      await t.tap(find.text('전문 보기'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    final original = UrlLauncherPlatform.instance;
    tearDown(() => UrlLauncherPlatform.instance = original);

    testWidgets('열지 못하면(false) 토스트로 알린다', (t) async {
      useIphoneViewport(t);
      UrlLauncherPlatform.instance = _Launcher(result: false);
      await openFullText(t);
      expect(find.text('약관 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('예외가 나도 전파되지 않고 토스트로 알린다', (t) async {
      useIphoneViewport(t);
      UrlLauncherPlatform.instance = _Launcher(throwOnLaunch: true);
      await openFullText(t);
      expect(t.takeException(), isNull);
      expect(find.text('약관 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('열리면 토스트가 없다', (t) async {
      useIphoneViewport(t);
      final launcher = _Launcher();
      UrlLauncherPlatform.instance = launcher;
      await openFullText(t);
      expect(launcher.launches, 1);
      expect(find.text('약관 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.'), findsNothing);
    });
  });
}
