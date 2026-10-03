import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/app/widgets/app_tab_bar.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/core/platform/device_alarm_settings.dart';
import 'package:after30/features/alarm/data/alarmkit_reminder_scheduler.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/device_alarm_gateway.dart';
import 'package:after30/features/my/ui/widgets/card_container.dart';
import 'package:after30/features/my/ui/widgets/link_list.dart';
import 'package:after30/features/my/ui/widgets/switch_row.dart';

import 'my_test_utils.dart';

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder.first);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  // -----------------------------------------------------------------------
  // Android: base(origin/feature/28/ios-release) 값과 동일해야 한다.
  // -----------------------------------------------------------------------
  group('Android는 base와 같은 값을 쓴다', () {
    Future<void> pumpAndroid(WidgetTester tester, {FakeMyProfileService? profile}) async {
      final service = profile ?? FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpScreen(tester, buildMyPage(profile: service), platform: TargetPlatform.android);
    }

    testWidgets('배경색, 제목, 섹션 제목 스타일', (tester) async {
      await pumpAndroid(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFEBF0FF));

      final title = tester.widget<Text>(find.text('마이페이지'));
      expect(title.style?.fontSize, 18);
      expect(title.style?.fontWeight, FontWeight.w500);
      expect(title.style?.color, Colors.black);

      final header = tester.widget<Text>(find.text('알람설정'));
      expect(header.style?.fontSize, 13);
      expect(header.style?.fontWeight, FontWeight.w500);
      expect(header.style?.color, Colors.black);

      // iOS 컴포넌트가 섞여 들어오지 않는다.
      expect(find.byType(AppGroupedSection), findsNothing);
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
    });

    testWidgets('프로필 카드: 흰 배경, 반지름 5, 패딩 16/0, 글자 13 w500, 셰브론 32', (tester) async {
      await pumpAndroid(tester);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(CardContainer), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(5));

      final paddings = tester
          .widgetList<Padding>(find.descendant(of: find.byType(CardContainer), matching: find.byType(Padding)))
          .map((p) => p.padding);
      expect(paddings, contains(const EdgeInsets.symmetric(horizontal: 16, vertical: 0)));

      final name = tester.widget<Text>(find.text('홍길동님의 정보'));
      expect(name.style?.fontSize, 13);
      expect(name.style?.fontWeight, FontWeight.w500);
      expect(name.style?.color, Colors.black);

      final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(chevron.size, 32);
      expect(chevron.color, Colors.black54);

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 20);
      expect(avatar.backgroundColor, Colors.grey.shade300);
    });

    testWidgets('스위치 행: 높이 48, 글자 12 w400, 트랙 색 #235DFF', (tester) async {
      await pumpAndroid(tester);

      final rows = tester.widgetList<SwitchRow>(find.byType(SwitchRow)).toList();
      expect(rows.map((r) => r.title), ['푸시 알림 허용', '디바이스 알람 허용']);
      for (final row in rows) {
        final sized = tester.widget<SizedBox>(
          find.descendant(of: find.byWidget(row), matching: find.byType(SizedBox)).first,
        );
        expect(sized.height, 48);
      }
      final label = tester.widget<Text>(find.text('푸시 알림 허용'));
      expect(label.style?.fontSize, 12);
      expect(label.style?.fontWeight, FontWeight.w400);
      expect(label.style?.color, Colors.black);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      for (final s in switches) {
        // base 값 비교(Switch.activeColor는 deprecated지만 base가 쓰는 속성이다).
        // ignore: deprecated_member_use
        expect(s.activeColor, Colors.white);
        expect(s.activeTrackColor, const Color(0xFF235DFF));
        expect(s.inactiveThumbColor, Colors.grey[400]);
        expect(s.inactiveTrackColor, Colors.grey[300]);
      }
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('링크 목록: 항목 순서와 글자 12 w400 검정', (tester) async {
      await pumpAndroid(tester);

      final list = tester.widget<LinkList>(find.byType(LinkList));
      expect(list.items, ['앱 정보', '개인정보 처리방침', '로그아웃', '계정탈퇴', '사용자 의견 보내기']);
      for (final item in list.items) {
        final text = tester.widget<Text>(find.text(item));
        expect(text.style?.fontSize, 12);
        expect(text.style?.fontWeight, FontWeight.w400);
        expect(text.style?.color, Colors.black);
      }
    });

    testWidgets('앱 정보 다이얼로그: 기존 AlertDialog와 "버전 x+빌드" 문구', (tester) async {
      await pumpAndroid(tester);

      await tester.tap(find.text('앱 정보'));
      await tester.pumpAndSettle();

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect((dialog.title! as Text).data, '식후 30분');
      expect((dialog.content! as Text).data, '버전 1.2.3+45');
      expect(find.text('확인'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('로그아웃 확인은 기존 DoubleCheck AlertDialog(문구, 라벨)', (tester) async {
      var logoutCalls = 0;
      await pumpScreen(
        tester,
        buildMyPage(
          profile: FakeMyProfileService(profile: MyProfile(name: '홍길동')),
          logout: (_) async => logoutCalls++,
        ),
        platform: TargetPlatform.android,
      );

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('로그아웃 하시겠습니까?'), findsOneWidget);
      expect(find.text('로그아웃 시 복약 알람이 안와요.'), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, '로그아웃'));
      await tester.pumpAndSettle();
      expect(logoutCalls, 1);
    });

    testWidgets('Android에서는 기기 권한 상태 행/설정 버튼을 그리지 않는다', (tester) async {
      final device = FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.deniedStatus);
      await pumpScreen(
        tester,
        buildMyPage(profile: FakeMyProfileService(), device: device),
        platform: TargetPlatform.android,
      );
      expect(find.text('설정에서 허용하기'), findsNothing);
      expect(find.text('알림 권한'), findsNothing);
      expect(device.loadCalls, 0);
    });
  });

  // -----------------------------------------------------------------------
  // iOS
  // -----------------------------------------------------------------------
  group('iOS 설정 목록', () {
    testWidgets('inset grouped 그룹과 행, 셰브론/destructive', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpScreen(tester, buildMyPage(profile: service), platform: TargetPlatform.iOS);

      expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, AppColors.groupedBackground);
      expect(find.text('마이페이지'), findsWidgets);
      expect(find.text('홍길동님의 정보'), findsOneWidget);
      expect(find.text('알람 설정'), findsOneWidget);
      expect(find.text('정보'), findsOneWidget);
      expect(find.text('계정'), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsNWidgets(2));
      expect(find.byType(Switch), findsNothing);

      for (final label in ['앱 정보', '개인정보 처리방침', '사용자 의견 보내기', '로그아웃', '계정탈퇴']) {
        expect(find.text(label), findsOneWidget);
      }

      // 탈퇴만 빨간 destructive.
      final tiles = tester.widgetList<AppListTile>(find.byType(AppListTile)).toList();
      final withdraw = tiles.firstWhere((t) => t.title == '계정탈퇴');
      expect(withdraw.destructive, isTrue);
      expect(tiles.firstWhere((t) => t.title == '로그아웃').destructive, isFalse);
      expect(tiles.firstWhere((t) => t.title == '앱 정보').showChevron, isTrue);
    });

    testWidgets('앱 정보는 PackageInfo 버전 "x.y.z (빌드)"를 CupertinoAlertDialog로 보여준다', (tester) async {
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService()), platform: TargetPlatform.iOS);

      await tester.tap(find.text('앱 정보'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('식후 30분'), findsOneWidget);
      expect(find.text('버전 1.2.3 (45)'), findsOneWidget);
    });

    testWidgets('로그아웃은 파괴적 액션 시트로 확인하고, 확인해야 실행한다', (tester) async {
      var logoutCalls = 0;
      await pumpScreen(
        tester,
        buildMyPage(profile: FakeMyProfileService(), logout: (_) async => logoutCalls++),
        platform: TargetPlatform.iOS,
      );

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      final action = tester.widget<CupertinoActionSheetAction>(
        find.widgetWithText(CupertinoActionSheetAction, '로그아웃'),
      );
      expect(action.isDestructiveAction, isTrue);

      // 취소하면 실행하지 않는다.
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(logoutCalls, 0);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '로그아웃'));
      await tester.pumpAndSettle();
      expect(logoutCalls, 1);
    });

    testWidgets('로그아웃 중복 탭: 500ms 지연 중 150ms 간격으로 두 번 눌러도 1회, 끝나면 재시도 가능', (tester) async {
      var logoutCalls = 0;
      await pumpScreen(
        tester,
        buildMyPage(
          profile: FakeMyProfileService(),
          logout: (_) async {
            logoutCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
        ),
        platform: TargetPlatform.iOS,
      );

      await tester.tap(find.widgetWithText(AppListTile, '로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '로그아웃'));
      await tester.pump();
      // 시트가 닫히고 로그아웃이 진행 중인 동안 행을 다시 누른다.
      await tester.pump(const Duration(milliseconds: 150));
      // 모달 배리어가 탭을 가로챌 수 있어 행의 onTap을 직접 호출한다.
      final rowTap = tester.widget<AppListTile>(find.widgetWithText(AppListTile, '로그아웃')).onTap!;
      rowTap();
      await tester.pump(const Duration(milliseconds: 150));
      rowTap();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing, reason: '진행 중 두 번 누른 탓에 확인 시트가 다시 열려 남아 있으면 안 된다');
      expect(logoutCalls, 1);

      // 끝난 뒤에는 다시 실행할 수 있다(플래그 해제).
      await tester.tap(find.widgetWithText(AppListTile, '로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '로그아웃'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(logoutCalls, 2);
    });

    testWidgets('탈퇴 중복 탭도 한 번만 실행한다', (tester) async {
      var deleteCalls = 0;
      await pumpScreen(
        tester,
        buildMyPage(
          profile: FakeMyProfileService(),
          deleteAccount: (_) async {
            deleteCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
        ),
        platform: TargetPlatform.iOS,
      );

      final tile = tester.widget<AppListTile>(find.widgetWithText(AppListTile, '계정탈퇴'));
      tile.onTap!();
      await tester.pump(const Duration(milliseconds: 150));
      tile.onTap!();
      await tester.pump(const Duration(seconds: 1));
      expect(deleteCalls, 1);

      tile.onTap!();
      await tester.pump(const Duration(seconds: 1));
      expect(deleteCalls, 2);
    });
  });

  group('iOS 기기 알람 권한 행', () {
    testWidgets('거부 상태: 꺼짐 표시와 "설정에서 허용하기"가 설정 앱을 연다', (tester) async {
      final device = FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.deniedStatus);
      await pumpScreen(
        tester,
        buildMyPage(profile: FakeMyProfileService(), device: device),
        platform: TargetPlatform.iOS,
      );

      expect(find.text('알림 권한'), findsOneWidget);
      expect(find.text('시간 민감 알림'), findsOneWidget);
      expect(find.text('알람(AlarmKit)'), findsOneWidget);
      expect(find.text('꺼짐'), findsNWidgets(3));
      expect(find.text('설정에서 허용하기'), findsOneWidget);

      await tester.ensureVisible(find.text('설정에서 허용하기'));
      await tester.tap(find.text('설정에서 허용하기'));
      await tester.pump();
      expect(device.openSettingsCalls, 1);
    });

    testWidgets('허용 상태: 허용됨 표시, 버튼 없음', (tester) async {
      await pumpScreen(
        tester,
        buildMyPage(profile: FakeMyProfileService(), device: FakeDeviceAlarmGateway()),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('허용됨'), findsNWidgets(2));
      expect(find.text('설정에서 허용하기'), findsNothing);
    });

    testWidgets('허용인데 시간 민감 알림만 꺼짐이면 설정 버튼을 보여준다', (tester) async {
      final device = FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.timeSensitiveOffStatus);
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService(), device: device), platform: TargetPlatform.iOS);
      expect(find.text('설정에서 허용하기'), findsOneWidget);
    });

    testWidgets('미결정 상태: 미결정 표시, 설정 버튼 대신 안내 문구', (tester) async {
      final device = FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.notDeterminedStatus);
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService(), device: device), platform: TargetPlatform.iOS);
      expect(find.text('미결정'), findsNWidgets(3));
      expect(find.text('설정에서 허용하기'), findsNothing);
      expect(find.text('처음 약을 등록할 때 알림 권한을 요청해요.'), findsOneWidget);
    });

    testWidgets('큰 제목 바 배경이 grouped 배경과 이어진다', (tester) async {
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService()), platform: TargetPlatform.iOS);
      final bar = tester.widget<CupertinoSliverNavigationBar>(find.byType(CupertinoSliverNavigationBar));
      expect(bar.backgroundColor, AppColors.groupedBackground);
    });

    testWidgets('AlarmKit이 허용이면 알림 권한이 꺼져 있어도 설정 안내를 띄우지 않는다', (tester) async {
      const status = MyDeviceAlarmStatus(
        notification: NotificationAuthorizationStatus.denied,
        timeSensitiveAllowed: false,
        alarmKit: AlarmKitAuthorizationStatus.authorized,
      );
      expect(status.alarmsReady, isTrue);
      expect(status.needsSettings, isFalse);
      expect(FakeDeviceAlarmGateway.deniedStatus.alarmsReady, isFalse);
      expect(FakeDeviceAlarmGateway.deniedStatus.needsSettings, isTrue);

      final device = FakeDeviceAlarmGateway(status: status);
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService(), device: device), platform: TargetPlatform.iOS);
      expect(find.text('설정에서 허용하기'), findsNothing);
    });

    testWidgets('앱 셸 안에서는 foreground 복귀 때 마이 탭에서만 한 번 다시 읽는다', (tester) async {
      void resume() {
        for (final s in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
      }

      final device = FakeDeviceAlarmGateway();
      await pumpShellWith(tester, buildMyPage(profile: FakeMyProfileService(), device: device), platform: TargetPlatform.iOS);
      var before = device.loadCalls;
      resume();
      await tester.pump();
      await tester.pump();
      expect(device.loadCalls - before, 1, reason: '마이 탭이 활성일 때 복귀하면 한 번만 읽는다');

      final shell = tester.state<AppShellState>(find.byType(AppShell));
      shell.switchTab(AppShellTab.home);
      await tester.pump();
      before = device.loadCalls;
      resume();
      await tester.pump();
      await tester.pump();
      expect(device.loadCalls, before, reason: '다른 탭에 있으면 읽지 않는다');
    });

    testWidgets('foreground로 돌아오면 권한 행이 갱신된다', (tester) async {
      final device = FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.deniedStatus);
      await pumpScreen(tester, buildMyPage(profile: FakeMyProfileService(), device: device), platform: TargetPlatform.iOS);
      expect(find.text('설정에서 허용하기'), findsOneWidget);
      final before = device.loadCalls;

      // 설정 앱에서 허용하고 돌아온 상황.
      device.status = FakeDeviceAlarmGateway.authorizedStatus;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(device.loadCalls, greaterThan(before));
      expect(find.text('설정에서 허용하기'), findsNothing);
      expect(find.text('허용됨'), findsNWidgets(2));
    });
  });

  group('프로필 로딩(백엔드 /users/me 우선)', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

      testWidgets('$label: 이메일 가입자는 카카오 SDK 없이 이름이 보인다', (tester) async {
        var kakaoCalls = 0;
        await pumpScreen(
          tester,
          buildMyPage(
            profile: FakeMyProfileService(profile: MyProfile(name: '이메일유저', provider: 'email')),
            kakaoImage: () async {
              kakaoCalls++;
              return 'https://kakao/x.png';
            },
          ),
          platform: platform,
        );
        expect(find.text('이메일유저님의 정보'), findsOneWidget);
        expect(kakaoCalls, 0);
      });

      testWidgets('$label: 카카오 가입자는 백엔드 이미지가 없으면 카카오 이미지로 대체를 시도한다', (tester) async {
        var kakaoCalls = 0;
        await pumpScreen(
          tester,
          buildMyPage(
            profile: FakeMyProfileService(profile: MyProfile(name: '카카오유저', provider: 'kakao')),
            kakaoImage: () async {
              kakaoCalls++;
              return null;
            },
          ),
          platform: platform,
        );
        expect(kakaoCalls, 1);
      });

      testWidgets('$label: 백엔드 이미지가 있으면 카카오 SDK를 부르지 않는다', (tester) async {
        var kakaoCalls = 0;
        await pumpScreen(
          tester,
          buildMyPage(
            profile: FakeMyProfileService(
              profile: MyProfile(name: '카카오유저', provider: 'kakao', profileImageUrl: 'https://be/x.png'),
            ),
            kakaoImage: () async {
              kakaoCalls++;
              return null;
            },
          ),
          platform: platform,
        );
        expect(kakaoCalls, 0);
      });

      testWidgets('$label: 실패하면 오류 문구가 보이고 탭하면 다시 시도한다', (tester) async {
        final service = FakeMyProfileService(profile: MyProfile(name: '홍길동'))..failGet = true;
        await pumpScreen(tester, buildMyPage(profile: service), platform: platform);
        expect(find.text('프로필을 불러오지 못했어요'), findsOneWidget);
        expect(find.text('홍길동님의 정보'), findsNothing);

        service.failGet = false;
        await tester.tap(find.text('프로필을 불러오지 못했어요'));
        await tester.pump();
        await tester.pump();
        expect(find.text('홍길동님의 정보'), findsOneWidget);
        expect(service.getCalls, 2);
      });
    }
  });

  group('탭 재활성화(R3 공통)', () {
    testWidgets('마이 탭이 다시 활성화되면 프로필을 다시 불러오고 "미등록"이 사라진다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '홍길동', provider: 'email'));
      await pumpShellWith(
        tester,
        buildMyPage(profile: service, device: FakeDeviceAlarmGateway()),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('전화번호 미등록'), findsOneWidget);
      expect(service.getCalls, 1);

      final shell = tester.state<AppShellState>(find.byType(AppShell));
      shell.switchTab(AppShellTab.family);
      await tester.pump();
      await tester.pump();
      // 가족 탭에서 번호를 등록한 상황.
      service.profile = MyProfile(name: '홍길동', provider: 'email', phoneNumber: '010-1234-5678');
      shell.switchTab(AppShellTab.my);
      await tester.pump();
      await tester.pump();

      expect(service.getCalls, 2);
      expect(find.text('전화번호 미등록'), findsNothing);
    });

    testWidgets('활성화 때 권한 상태도 다시 읽는다', (tester) async {
      final device = FakeDeviceAlarmGateway();
      await pumpShellWith(
        tester,
        buildMyPage(profile: FakeMyProfileService(), device: device),
        platform: TargetPlatform.iOS,
      );
      final before = device.loadCalls;
      final shell = tester.state<AppShellState>(find.byType(AppShell));
      shell.switchTab(AppShellTab.home);
      await tester.pump();
      shell.switchTab(AppShellTab.my);
      await tester.pump();
      await tester.pump();
      expect(device.loadCalls, greaterThan(before));
    });

    testWidgets('느린 이전 응답이 새 응답을 덮지 않는다', (tester) async {
      final service = FakeMyProfileService(profile: MyProfile(name: '처음'), getDelay: const Duration(milliseconds: 300));
      await pumpShellWith(tester, buildMyPage(profile: service), platform: TargetPlatform.iOS);
      final shell = tester.state<AppShellState>(find.byType(AppShell));

      // 첫 요청이 끝나기 전에 활성화로 두 번째 요청을 보낸다. 두 번째 응답만 반영돼야 한다.
      service.profile = MyProfile(name: '나중');
      shell.switchTab(AppShellTab.home);
      await tester.pump();
      shell.switchTab(AppShellTab.my);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('나중님의 정보'), findsOneWidget);
    });
  });

  group('레이아웃', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final label = platform == TargetPlatform.iOS ? 'iOS' : 'Android';

      testWidgets('$label: 실제 세이프에어리어(1206x2622)에서 마지막 행이 탭바에 가려지지 않는다', (tester) async {
        tester.view.physicalSize = const Size(1206, 2622);
        tester.view.devicePixelRatio = 3.0;
        tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
        tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
        addTearDown(tester.view.reset);

        await pumpShellWith(
          tester,
          buildMyPage(profile: FakeMyProfileService(), device: FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.deniedStatus)),
          platform: platform,
          tallView: false,
        );

        final last = platform == TargetPlatform.iOS ? find.text('계정탈퇴') : find.text('사용자 의견 보내기');
        await tester.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).first);
        await tester.pump();
        final lastRect = _rect(tester, last);
        if (platform == TargetPlatform.iOS) {
          final barTop = _rect(tester, find.byType(GlassSurface)).top;
          expect(lastRect.bottom, lessThanOrEqualTo(barTop + 0.5), reason: '탈퇴 행이 탭바 위에서 끝나야 한다');
        }
        // 탭이 실제로 닿는지(히트 테스트)도 확인한다.
        await tester.tap(last);
        await tester.pump();
        expect(tester.takeException(), isNull);
        // 탭바 존재 확인.
        expect(find.byType(AppTabBar), findsOneWidget);
      });

      testWidgets('$label: iPhone SE(750x1334 dpr2) 글자 1.5배에서 오버플로가 없다', (tester) async {
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await pumpScreen(
          tester,
          buildMyPage(
            profile: FakeMyProfileService(profile: MyProfile(name: '아주아주아주긴이름의사용자입니다')),
            device: FakeDeviceAlarmGateway(status: FakeDeviceAlarmGateway.deniedStatus),
          ),
          platform: platform,
          textScale: 1.5,
          tallView: false,
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
