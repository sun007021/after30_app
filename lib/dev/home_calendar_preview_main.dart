// 디버그 전용 프리뷰 엔트리포인트(plan §6 W7 검증 절차).
//
// 홈/캘린더 화면은 로그인된 백엔드 세션이 있어야 실제 데이터를 볼 수
// 있는데, Firebase/Kakao 초기화 없이 시뮬레이터에서 iOS 스타일을 눈으로
// 확인하기 위해 이 엔트리로 [AppShell] 안에 실제 [HomePage]/[CalendarPage]를
// 가짜 데이터로 띄운다. `flutter build ios --simulator`는 Xcode 26.6 +
// Flutter 3.38.3 조합에서 lipo 오류로 실패하므로(plan §3 각주),
// `flutter run -t lib/dev/home_calendar_preview_main.dart`로 실행한다.
// 릴리스 빌드 진입점이 아니므로 main.dart에서 import하지 않는다.
import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/ui/calendar_page.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/home/ui/home.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const _HomeCalendarPreviewApp());
}

class _HomeCalendarPreviewApp extends StatelessWidget {
  const _HomeCalendarPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '홈/캘린더 프리뷰',
      theme: AppTheme.build(),
      // CupertinoDatePicker(monthYear) 등 Cupertino 위젯이 한국어로 뜨도록
      // main.dart와 동일한 로컬라이제이션 설정을 쓴다.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      debugShowCheckedModeBanner: false,
      home: AppShell(
        pageBuilders: [
          (context, args) => const _StubTabPage(index: AppShellTab.alarm),
          (context, args) => const _StubTabPage(index: AppShellTab.family),
          (context, args) => Stack(
                children: [
                  HomePage(
                    fetchMedications: _PreviewData.fetchMedications,
                    familyService: _PreviewFamilyService(),
                  ),
                  // 스크린샷 검증용: 시뮬레이터에 손으로 탭할 수 없는 환경에서
                  // 홈 → 기록 탭으로 자동 전환한다(§6 W7 검증 절차). 실제
                  // 화면 코드는 건드리지 않는다.
                  const _AutoTabSwitcher(after: Duration(seconds: 4), target: AppShellTab.history),
                ],
              ),
          (context, args) => CalendarPage(fetchMedications: _PreviewData.fetchMedications),
          (context, args) => const _StubTabPage(index: AppShellTab.my),
        ],
      ),
    );
  }
}

/// 스크린샷 검증 전용 자동 탭 전환 위젯(§6 W7). 시뮬레이터에 터치 입력을
/// 보낼 수 없는 환경에서 `flutter run`만으로 여러 탭의 스크린샷을 순서대로
/// 찍을 수 있게 한다. 화면에는 아무것도 그리지 않는다.
class _AutoTabSwitcher extends StatefulWidget {
  const _AutoTabSwitcher({required this.after, required this.target});

  final Duration after;
  final int target;

  @override
  State<_AutoTabSwitcher> createState() => _AutoTabSwitcherState();
}

class _AutoTabSwitcherState extends State<_AutoTabSwitcher> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.after, () {
      if (!mounted) return;
      AppShell.maybeOf(context)?.switchTab(widget.target);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

const _tabLabels = ['알람', '가족', '홈', '기록', '마이'];

/// 홈/기록 탭 이외의 탭은 W7 검증 범위 밖이라 가벼운 스텁으로 채운다.
class _StubTabPage extends StatelessWidget {
  const _StubTabPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_tabLabels[index]} 탭(W7 검증 범위 밖)')),
      bottomNavigationBar: AlarmBottomNavigation(currentIndex: index),
      body: const Center(child: Text('이 프리뷰는 홈/기록 탭만 확인합니다')),
    );
  }
}

/// 실제 백엔드 없이 홈/캘린더를 채울 가짜 복약 데이터.
class _PreviewData {
  _PreviewData._();

  static Medication _med({
    required String time,
    required DateTime date,
    String status = 'pending',
    String name = '오메가3',
    int scheduleId = 1,
    DateTime? takenAt,
  }) {
    return Medication(
      id: '${scheduleId}_${date.toIso8601String()}_$time',
      name: name,
      dosage: '1정',
      time: time,
      date: date,
      status: status,
      scheduleId: scheduleId,
      takenAt: takenAt,
    );
  }

  /// [HomeContent]/[CalendarPage]가 주는 [start, end] 범위(양끝 포함)의
  /// 날짜마다 오전/오후 복약 2건을 만들어 돌려준다. 오늘 오전 항목은 이미
  /// 복용 완료로 표시해 두 상태(완료/예정)를 한 화면에서 볼 수 있게 한다.
  static Future<List<Medication>> fetchMedications(DateTime start, DateTime end) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final days = end.difference(start).inDays.abs() + 1;
    final meds = <Medication>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final isToday = day.year == todayOnly.year && day.month == todayOnly.month && day.day == todayOnly.day;
      meds.add(_med(
        time: '09:00',
        date: day,
        name: '오메가3',
        scheduleId: 1,
        status: isToday ? 'taken' : 'pending',
        takenAt: isToday ? DateTime.now().toUtc().subtract(const Duration(hours: 9, minutes: -5)) : null,
      ));
      meds.add(_med(time: '21:00', date: day, name: '비타민D', scheduleId: 2));
    }
    return meds;
  }
}

/// 실제 네트워크 호출 없이 가족 게이지 행을 채우는 가짜 [FamilyService].
class _PreviewFamilyService extends FamilyService {
  @override
  Future<HomeDashboard> getHomeDashboard({DateTime? targetDate}) async {
    return HomeDashboard(
      date: DateTime.now(),
      membersSummary: [
        MemberMedicationSummary(
          userId: 1,
          userName: '엄마',
          totalScheduled: 2,
          takenCount: 2,
          pendingCount: 0,
          missedCount: 0,
          complianceRate: 1.0,
        ),
        MemberMedicationSummary(
          userId: 2,
          userName: '아빠',
          totalScheduled: 2,
          takenCount: 1,
          pendingCount: 1,
          missedCount: 0,
          complianceRate: 0.5,
        ),
      ],
    );
  }

  @override
  Future<Map<int, int>> getUserIdToGroupIdMap() async => const {1: 1, 2: 1};
}
