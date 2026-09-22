import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/app/widgets/app_tab_bar.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_haptics.dart';
import 'package:after30/features/alarm/ui/alarm_list.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:after30/features/my/my_page.dart';

/// 탭 인덱스 상수(plan §6 W10 1항). 0:알람 1:가족 2:홈 3:기록 4:마이.
class AppShellTab {
  AppShellTab._();

  static const int alarm = 0;
  static const int family = 1;
  static const int home = 2;
  static const int history = 3;
  static const int my = 4;

  /// 탭 개수.
  static const int count = 5;
}

/// 탭 콘텐츠를 만드는 함수. [arguments]는 [AppShellState.switchTab]의
/// `arguments`로 전달된 값이며(없으면 null), 탭이 처음 만들어질 때와
/// arguments가 갱신될 때 다시 호출된다.
typedef AppShellPageBuilder = Widget Function(BuildContext context, Object? arguments);

/// 앱 셸: 5개 탭을 [IndexedStack]으로 구성하고, 탭마다 독립된 [Navigator]를
/// 둬서 화면 상태(스크롤 위치 등)를 유지한다(plan §6 W10 1항).
///
/// 다른 화면에서는 `AppShell.of(context).switchTab(index)`로 탭을 전환한다.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = AppShellTab.home,
    this.initialArguments,
    List<AppShellPageBuilder>? pageBuilders,
  }) : pageBuilders = pageBuilders ?? _defaultPageBuilders;

  /// 시작 탭(기본값: 홈).
  final int initialIndex;

  /// 시작 탭에 전달할 인자(예: 특정 가족 그룹으로 바로 진입).
  final Object? initialArguments;

  /// 탭별 화면 빌더. 테스트에서 실제 기능 화면 대신 가벼운 스텁 페이지를
  /// 주입할 수 있도록 외부에서 지정할 수 있게 한다. 길이는 반드시
  /// [AppShellTab.count]와 같아야 한다.
  final List<AppShellPageBuilder> pageBuilders;

  static const List<AppShellPageBuilder> _defaultPageBuilders = [
    _buildAlarmTab,
    _buildFamilyTab,
    _buildHomeTab,
    _buildHistoryTab,
    _buildMyTab,
  ];

  static Widget _buildAlarmTab(BuildContext context, Object? args) => const AlarmPage();

  static Widget _buildFamilyTab(BuildContext context, Object? args) =>
      FamilyPage(initialGroupId: args is int ? args : null);

  static Widget _buildHomeTab(BuildContext context, Object? args) => const HomePage();

  static Widget _buildHistoryTab(BuildContext context, Object? args) => const CalendarPage();

  static Widget _buildMyTab(BuildContext context, Object? args) => const MyPage();

  /// 가장 가까운 [AppShellState]를 찾는다. 셸 밖에서 호출하면 assert에 걸린다.
  static AppShellState of(BuildContext context) {
    final state = context.findAncestorStateOfType<AppShellState>();
    assert(state != null, 'AppShell.of()는 AppShell 하위 트리에서만 호출할 수 있습니다.');
    return state!;
  }

  /// 현재 위치가 [AppShell] 안인지 확인한다(예: `AlarmBottomNavigation`이
  /// 셸 안에서는 빈 위젯을 렌더링하기 위해 사용).
  static bool isInside(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>() != null;
  }

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int _currentIndex = widget.initialIndex;
  late final List<Object?> _tabArguments = List<Object?>.filled(AppShellTab.count, null);
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    AppShellTab.count,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _tabArguments[_currentIndex] = widget.initialArguments;
  }

  /// 현재 활성 탭 인덱스.
  int get currentIndex => _currentIndex;

  /// 탭을 전환한다.
  ///
  /// - 이미 활성화된 탭을 다시 지정하면 해당 탭의 내비게이션 스택을
  ///   루트까지 pop한다(iOS HIG의 "활성 탭 재탭 = 루트로" 동작, §4.3).
  /// - [popToRoot]가 true면 전환과 함께 대상 탭도 루트까지 pop한다.
  /// - [arguments]를 지정하면 대상 탭의 루트 화면을 새 인자로 다시 만든다
  ///   (예: 특정 가족 그룹으로 이동). 화면 전체를 새로 만들므로 기존
  ///   `pushReplacement(FamilyPage(initialGroupId: ...))` 호출과 동일하게
  ///   해당 탭의 상태가 초기화된다.
  void switchTab(int index, {bool popToRoot = false, Object? arguments}) {
    assert(index >= 0 && index < AppShellTab.count);
    final isSameTab = index == _currentIndex;

    if (arguments != null) {
      _tabArguments[index] = arguments;
      final navState = _navigatorKeys[index].currentState;
      navState?.popUntil((route) => route.isFirst);
      navState?.pushReplacement(_rootRoute(index, arguments));
    } else if (isSameTab || popToRoot) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }

    if (!isSameTab) {
      AppHaptics.selection(context);
      setState(() => _currentIndex = index);
    }
  }

  PageRoute<void> _rootRoute(int index, Object? arguments) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, _, __) => widget.pageBuilders[index](context, arguments),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  /// Android 뒤로 가기 처리(plan §6 W10 1항): 현재 탭 안에서 pop → 홈 탭으로
  /// 이동 → (홈 탭 루트에서) 앱 종료.
  ///
  /// `@visibleForTesting`: 위젯 테스트에서 `tester.binding.handlePopRoute()`
  /// 대신 이 메서드를 직접 호출해 결정론적으로 검증할 수 있게 한다.
  @visibleForTesting
  Future<void> handleBackButton() async {
    final navState = _navigatorKeys[_currentIndex].currentState;
    if (navState != null && navState.canPop()) {
      navState.pop();
      return;
    }
    if (_currentIndex != AppShellTab.home) {
      switchTab(AppShellTab.home);
      return;
    }
    try {
      await SystemNavigator.pop();
    } catch (_) {
      // 테스트 등 플랫폼 채널이 없는 환경에서는 조용히 무시한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    final reservedBottom = cupertino ? AppTabBar.reservedBottomHeight(context) : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBackButton();
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: List.generate(AppShellTab.count, (i) {
                return _AppShellTabView(
                  key: ValueKey('app-shell-tab-$i'),
                  navigatorKey: _navigatorKeys[i],
                  builder: widget.pageBuilders[i],
                  initialArguments: _tabArguments[i],
                  reservedBottom: reservedBottom,
                );
              }),
            ),
            if (!cupertino)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppTabBar(currentIndex: _currentIndex, onTap: switchTab),
              ),
            if (cupertino)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AppTabBar(currentIndex: _currentIndex, onTap: switchTab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 탭 하나를 위한 독립된 [Navigator] 컨테이너.
///
/// [IndexedStack]이 비활성 탭도 트리에서 유지하므로, 각 탭의 [Navigator]는
/// 계속 살아있고 스크롤 위치/입력 상태가 보존된다. iOS에서는 플로팅 탭바에
/// 콘텐츠가 가리지 않도록 [reservedBottom]만큼 [MediaQuery] 하단 패딩을
/// 늘려서 내려보낸다(기존 화면들이 `MediaQuery.viewPadding.bottom`을 읽어
/// 여백을 계산하던 방식을 그대로 활용).
class _AppShellTabView extends StatelessWidget {
  const _AppShellTabView({
    super.key,
    required this.navigatorKey,
    required this.builder,
    required this.initialArguments,
    required this.reservedBottom,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AppShellPageBuilder builder;
  final Object? initialArguments;
  final double reservedBottom;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator(
      key: navigatorKey,
      onGenerateInitialRoutes: (navigatorState, initialRoute) {
        return [
          PageRouteBuilder<void>(
            pageBuilder: (routeContext, _, __) => builder(routeContext, initialArguments),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ];
      },
    );

    if (reservedBottom <= 0) return navigator;

    final mediaQuery = MediaQuery.of(context);
    final effectiveBottom = reservedBottom > mediaQuery.padding.bottom
        ? reservedBottom
        : mediaQuery.padding.bottom;

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(bottom: effectiveBottom),
        viewPadding: mediaQuery.viewPadding.copyWith(bottom: effectiveBottom),
      ),
      child: navigator,
    );
  }
}
