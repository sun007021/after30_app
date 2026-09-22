import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:after30/app/app_routes.dart';
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

/// 탭이 다시 활성화될 때(전환 또는 재탭) 알림을 받고 싶은 탭 루트 화면이
/// 구현하는 믹스인(M2). 예: 홈 탭은 다른 탭에 있다가 돌아왔을 때 최신
/// 데이터를 다시 불러와야 한다.
///
/// [AppShell]은 탭을 [IndexedStack]으로 유지해 상태를 보존하므로(§6 W10
/// 1항), 탭 화면의 `initState`는 최초 방문 때 딱 한 번만 호출된다. 이
/// 믹스인을 구현하고 [AppShellTabAware.wrap]으로 감싸면 재방문마다
/// [onTabActivated]가 호출된다.
///
/// 사용 예:
/// ```dart
/// class _HomePageState extends State<HomePage> with AppShellTabAware {
///   @override
///   void onTabActivated() => _reload();
/// }
/// ```
/// 그리고 `build()`가 반환하는 위젯 트리 최상단을
/// `AppShellTabAware.wrap(context, this, child)`로 감싼다(자세한 배선은
/// 각 탭 담당 위젯에서 한다 — W5/W7/W8/W9 참고).
mixin AppShellTabAware<T extends StatefulWidget> on State<T> {
  /// 이 탭이 (다른 탭에 있다가) 다시 활성화될 때 호출된다.
  void onTabActivated();
}

/// [AppShellTabAware]를 [AppShell]의 탭 활성화 알림에 연결하는 도우미 위젯.
/// 탭 화면의 `build()` 최상단에서 이 위젯으로 감싸면, 셸이 탭을 전환할
/// 때마다 (같은 탭이 다시 활성화된 경우) [AppShellTabAware.onTabActivated]가
/// 호출된다(M2).
class AppShellTabActivationListener extends StatefulWidget {
  const AppShellTabActivationListener({
    super.key,
    required this.tabIndex,
    required this.onActivated,
    required this.child,
  });

  final int tabIndex;
  final VoidCallback onActivated;
  final Widget child;

  @override
  State<AppShellTabActivationListener> createState() => _AppShellTabActivationListenerState();
}

class _AppShellTabActivationListenerState extends State<AppShellTabActivationListener> {
  Listenable? _activation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activation = AppShell.maybeOf(context)?.tabActivationListenable;
    if (!identical(activation, _activation)) {
      _activation?.removeListener(_handleChanged);
      _activation = activation;
      _activation?.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    _activation?.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    final shellState = AppShell.maybeOf(context);
    if (shellState == null) return;
    // 셸은 탭 전환이든 재탭이든(같은 탭 재선택) switchTab 끝에서 항상
    // 이 알림을 보낸다(ChangeNotifier라 값이 안 바뀌어도 울린다). 여기서는
    // 그 알림이 "내 탭이 지금 활성 탭인가"만 걸러낸다.
    if (shellState.currentIndex == widget.tabIndex) {
      widget.onActivated();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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

  /// [of]와 같지만 셸 밖에서 호출하면 null을 반환한다(m3). 셸 안팎에서 모두
  /// 쓰일 수 있는 위젯이 "셸 안이면 셸 기능을 쓰고, 아니면 건너뛴다"를
  /// 표현할 때 쓴다.
  static AppShellState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>();
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

  /// 아직 한 번도 방문하지 않은 탭은 실제 화면(및 그 Navigator)을 만들지
  /// 않는다(B2). 방문한 탭은 계속 [IndexedStack]에 남아 상태를 유지한다.
  late final Set<int> _visitedTabs = <int>{_currentIndex};

  /// 탭이 (재선택 포함) 활성화될 때마다 알림을 보내는 [ChangeNotifier](M2).
  /// 값 비교 없이 항상 알리는 게 핵심이다 — 같은 탭을 재탭해도(값이 바뀌지
  /// 않아도) [AppShellTabActivationListener]가 알림을 받아야 하므로
  /// [ValueNotifier]는 쓰지 않는다(값이 그대로면 알림을 생략하기 때문).
  final _TabActivationNotifier _tabActivation = _TabActivationNotifier();

  @override
  void initState() {
    super.initState();
    _tabArguments[_currentIndex] = widget.initialArguments;
  }

  @override
  void dispose() {
    _tabActivation.dispose();
    super.dispose();
  }

  /// 현재 활성 탭 인덱스.
  int get currentIndex => _currentIndex;

  /// 탭이 활성화될 때(전환 또는 재탭)마다 알림을 보내는 [Listenable](M2).
  /// [AppShellTabActivationListener]가 내부적으로 구독한다.
  Listenable get tabActivationListenable => _tabActivation;

  /// 탭을 전환한다.
  ///
  /// - 이미 활성화된 탭을 다시 지정하면 해당 탭의 내비게이션 스택을
  ///   루트까지 pop한다(iOS HIG의 "활성 탭 재탭 = 루트로" 동작, §4.3).
  /// - [popToRoot]가 true면 전환과 함께 대상 탭도 루트까지 pop한다.
  /// - [arguments]를 지정하면 대상 탭의 루트 화면을 새 인자로 다시 만든다
  ///   (예: 특정 가족 그룹으로 이동). [resetArguments]를 true로 주면
  ///   [arguments]가 null이어도(예: 특정 그룹 없이 가족 탭을 초기 상태로
  ///   되돌리는 경우, M6) 루트 화면을 다시 만든다. 화면 전체를 새로 만들기
  ///   때문에 기존 `pushReplacement(FamilyPage(initialGroupId: ...))` 호출과
  ///   동일하게 해당 탭의 상태가 초기화된다.
  /// - [popOriginToRoot]가 true면 전환을 호출한 "출발 탭"(현재 탭)의 스택도
  ///   함께 루트까지 pop한다(M3). 예: 홈 탭에서 가족 그룹 초대 플로우를 열고
  ///   완료 후 가족 탭으로 전환할 때, 홈 탭에 초대 플로우 화면들이 그대로
  ///   남아있지 않도록 한다.
  void switchTab(
    int index, {
    bool popToRoot = false,
    Object? arguments,
    bool resetArguments = false,
    bool popOriginToRoot = false,
  }) {
    assert(index >= 0 && index < AppShellTab.count);
    final originIndex = _currentIndex;
    final isSameTab = index == originIndex;
    final replacingArguments = arguments != null || resetArguments;

    if (replacingArguments) {
      _tabArguments[index] = arguments;
      // popUntil + pushReplacement 대신 pushAndRemoveUntil을 쓰면 중간에
      // 쌓여있던 화면들이 각자의 pop 애니메이션 없이 즉시 제거되고, 새
      // 루트 화면만 한 번 애니메이션된다(전환 시간이 0이므로 사실상
      // 즉시 바뀐다). popUntil을 먼저 호출하면 쌓인 화면 수만큼 pop
      // 트랜지션이 순차적으로 겹쳐 보이는 문제가 있었다(m5).
      _navigatorKeys[index].currentState?.pushAndRemoveUntil(
        _rootRoute(index, arguments),
        (route) => false,
      );
    } else if (isSameTab || popToRoot) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }

    if (popOriginToRoot && !isSameTab) {
      _navigatorKeys[originIndex].currentState?.popUntil((route) => route.isFirst);
    }

    if (!isSameTab) {
      setState(() {
        _currentIndex = index;
        _visitedTabs.add(index);
      });
    }
    // 재탭(같은 탭 재선택)이든 실제 전환이든, "활성화"로 취급해 M2 리스너에
    // 알린다.
    _tabActivation.notify();
  }

  PageRoute<void> _rootRoute(int index, Object? arguments) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, _, __) => widget.pageBuilders[index](context, arguments),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  /// 탭바 탭에서만 호출되는 래퍼(m2). 프로그래밍적인 [switchTab] 호출
  /// (예: 홈 화면에서 가족 그룹으로 바로 이동)에서는 선택 햅틱을 울리지
  /// 않고, 사용자가 실제로 탭바를 터치했을 때만 울린다.
  void _handleTabBarTap(int index) {
    if (index != _currentIndex) {
      AppHaptics.selection(context);
    }
    switchTab(index);
  }

  /// Android 뒤로 가기 처리(plan §6 W10 1항): 현재 탭 안에서 pop → 홈 탭으로
  /// 이동 → (홈 탭 루트에서) 앱 종료.
  ///
  /// `@visibleForTesting`: 위젯 테스트에서 `tester.binding.handlePopRoute()`
  /// 대신 이 메서드를 직접 호출해 결정론적으로 검증할 수 있게 한다.
  @visibleForTesting
  Future<void> handleBackButton() async {
    final navState = _navigatorKeys[_currentIndex].currentState;
    // pop() 대신 maybePop()을 써서, 서브 페이지가 PopScope로 뒤로 가기를
    // 가로채고 있으면(예: 저장 확인 다이얼로그) 그 의사를 존중한다(m1).
    if (navState != null && await navState.maybePop()) {
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final tabStack = IndexedStack(
      index: _currentIndex,
      children: List.generate(AppShellTab.count, (i) {
        // 방문한 적 없는 탭은 실제 화면을 만들지 않는다(B2). 예를 들어
        // 가족 탭의 FamilyPage.initState는 전화번호 등록 팝업을 예약할 수
        // 있는데, IndexedStack이 모든 탭을 한꺼번에 만들면 로그인 직후
        // 홈 화면 위에 그 팝업이 떠 버린다.
        if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
        return _AppShellTabView(
          key: ValueKey('app-shell-tab-$i'),
          navigatorKey: _navigatorKeys[i],
          builder: widget.pageBuilders[i],
          initialArguments: _tabArguments[i],
        );
      }),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBackButton();
      },
      child: Scaffold(
        // Android는 기존 화면들처럼 키보드가 올라오면 body가 그만큼
        // 줄어들게 한다. iOS는 각 탭 안의 화면(Scaffold)이 스스로 키보드를
        // 처리하므로 셸 레벨에서는 손대지 않는다.
        resizeToAvoidBottomInset: !cupertino,
        // iOS: 콘텐츠가 플로팅 탭바 아래까지 그대로 이어지게 한다(탭바는
        // 콘텐츠 위로 뜬다). body 자체는 아래 bottomNavigationBar 자리
        //때문에 줄어들지 않는다.
        extendBody: cupertino,
        body: cupertino
            ? Stack(
                children: [
                  Positioned.fill(child: tabStack),
                  // 키보드가 올라와 있는 동안은 플로팅 탭바를 숨긴다(키보드
                  // 위에 떠 있는 게 더 어색하다).
                  if (!keyboardOpen)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: AppTabBar(currentIndex: _currentIndex, onTap: _handleTabBarTap),
                      ),
                    ),
                ],
              )
            : tabStack,
        // Android: 탭바를 Scaffold의 bottomNavigationBar 슬롯에 그대로
        // 꽂아서(오버레이가 아니라) 기존 화면들의 레이아웃/키보드 동작이
        // 예전과 같게 한다(B3). iOS는 콘텐츠 위로 떠 있는 글래스 캡슐이라
        // 실제로 보이는 탭바는 위 Stack에서 그리지만, 이 슬롯을 비워두면
        // 안 된다: Flutter의 ScaffoldMessenger는 중첩된 Scaffold들 중
        // "가장 바깥쪽(root)" 하나에서만 SnackBar를 보여주는데, 셸의 이
        // Scaffold가 바로 그 루트다(각 화면 자신의 Scaffold가 아니다).
        // 여기 bottomNavigationBar가 null이면 화면이 무엇을 설정했든 상관
        // 없이 SnackBar가 탭바 아래로 깔린다(M1). 그래서 보이지 않는
        // 자리표시자로 같은 높이를 예약해 Scaffold의 SnackBar/FAB 자동
        // 배치 로직이 탭바 위로 띄우게 만든다(extendBody와 함께 써도
        // body 자체는 줄어들지 않는다).
        bottomNavigationBar: cupertino
            ? IgnorePointer(
                child: SizedBox(height: AppTabBar.reservedBottomHeight(context)),
              )
            : AppTabBar(currentIndex: _currentIndex, onTap: _handleTabBarTap),
      ),
    );
  }
}

/// 탭 하나를 위한 독립된 [Navigator] 컨테이너.
///
/// [IndexedStack]이 비활성 탭도 트리에서 유지하므로, 각 탭의 [Navigator]는
/// 계속 살아있고 스크롤 위치/입력 상태가 보존된다.
///
/// `onGenerateRoute`(공유 [generateTabRoute])를 둬서, 탭 안에서
/// `Navigator.of(context).pushNamed(...)`를 호출해도(예: 마이 탭의
/// `/my-info`) "onGenerateRoute was null"로 죽지 않는다(B1). 탭에 남으면 안
/// 되는 라우트는 [generateTabRoute]가 알아서 루트 내비게이터로 넘긴다.
class _AppShellTabView extends StatelessWidget {
  const _AppShellTabView({
    super.key,
    required this.navigatorKey,
    required this.builder,
    required this.initialArguments,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AppShellPageBuilder builder;
  final Object? initialArguments;

  @override
  Widget build(BuildContext context) {
    return Navigator(
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
      onGenerateRoute: generateTabRoute,
    );
  }
}

/// `notifyListeners()`는 [ChangeNotifier] 서브클래스의 인스턴스 멤버에서만
/// 호출할 수 있어서([AppShellState]는 [State]를 상속하므로 직접 상속할 수
/// 없다), 값 비교 없이 매번 알리는 아주 작은 전용 알림자를 둔다(M2).
class _TabActivationNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
