// 디버그 전용 프리뷰 엔트리포인트(plan §6 W8 검증 절차).
//
// 가족 화면은 로그인된 백엔드 세션이 있어야 실제 데이터를 볼 수 있는데,
// Firebase/Kakao 초기화 없이 시뮬레이터에서 iOS 스타일을 눈으로 확인하기
// 위해 이 엔트리로 [AppShell] 안에 실제 [FamilyPage]를 가짜 서비스로 띄운다.
// `flutter build ios --simulator`는 Xcode 26.6 + Flutter 3.38.3 조합에서
// lipo 오류로 실패하므로(plan §3 각주), 다음처럼 실행한다.
//
//   flutter run -d <simulator> -t lib/dev/family_preview_main.dart \
//     --dart-define=SCENE=banner|sheet|invite|actions|groupmenu --no-resident
//
// 시뮬레이터에 터치 입력을 보낼 수 없는 환경이라, SCENE에 따라 일정 시간 뒤
// 시트/페이지를 자동으로 연다(화면 코드는 건드리지 않는다). 릴리스 빌드
// 진입점이 아니므로 main.dart에서 import하지 않는다.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/app_theme.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/common/widgets/phone_register_dialog.dart';
import 'package:after30/features/family/data/family_service.dart';
import 'package:after30/features/family/models/family_dashboard.dart';
import 'package:after30/features/family/models/family_group.dart';
import 'package:after30/features/family/models/family_invitation.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/family/ui/family_group_manage_page.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/features/family/ui/family_page.dart';
import 'package:after30/features/my/data/my_profile_service.dart';
import 'package:after30/features/my/data/user_service.dart';
import 'package:after30/features/my/models/user_by_phone_response.dart';

const _scene = String.fromEnvironment('SCENE', defaultValue: 'banner');

final _rootKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const _FamilyPreviewApp());
  Future.delayed(const Duration(seconds: 4), _runScene);
}

final _profile = _PreviewProfileService();
final _family = _PreviewFamilyService();
final _users = _PreviewUserService();

class _FamilyPreviewApp extends StatelessWidget {
  const _FamilyPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '가족 프리뷰',
      navigatorKey: _rootKey,
      theme: AppTheme.build(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      debugShowCheckedModeBanner: false,
      home: AppShell(
        initialIndex: AppShellTab.family,
        pageBuilders: [
          (context, args) => const _StubTabPage(index: AppShellTab.alarm),
          (context, args) => FamilyPage(
                familyService: _family,
                profileService: _profile,
                userService: _users,
                fetchMemberMedications: _fetchMedications,
              ),
          (context, args) => const _StubTabPage(index: AppShellTab.home),
          (context, args) => const _StubTabPage(index: AppShellTab.history),
          (context, args) => const _StubTabPage(index: AppShellTab.my),
        ],
      ),
    );
  }
}

Future<void> _runScene() async {
  final context = _rootKey.currentContext;
  final navigator = _rootKey.currentState;
  if (context == null || navigator == null) return;
  switch (_scene) {
    case 'sheet':
      final profile = await _profile.getMyProfile();
      if (!context.mounted) return;
      showPhoneRegisterSheet(
        context: context,
        profile: profile,
        profileService: _profile,
        userService: _users,
      );
    case 'invite':
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => FamilyInviteExistingGroupInvitePage(
            groupId: 1,
            groupName: '우리 가족',
            familyService: _family,
            userService: _users,
            profileService: _profile,
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      for (final phone in ['010-9999-8888', '010-7777-6666']) {
        _typeIntoLastField(phone);
        await Future.delayed(const Duration(milliseconds: 800));
      }
    case 'actions':
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => FamilyGroupManagePage(
            groupId: 1,
            groupName: '우리 가족',
            familyService: _family,
            resolveCurrentUserId: (_) async => 1,
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      _tapAncestorOf(find: (w) => w is Icon && w.icon == CupertinoIcons.ellipsis);
    case 'groupmenu':
      _tapAncestorOf(find: (w) => w is Text && w.data == '우리 가족');
  }
}

/// 마지막 [EditableText]에 값을 넣고 제출한다(터치 없이 칩을 만들기 위함).
void _typeIntoLastField(String text) {
  EditableText? last;
  void visit(Element element) {
    if (element.widget is EditableText) last = element.widget as EditableText;
    element.visitChildren(visit);
  }

  _rootKey.currentContext?.visitChildElements(visit);
  final field = last;
  if (field == null) return;
  field.controller.text = text;
  field.onSubmitted?.call(text);
}

/// 조건에 맞는 위젯의 가장 가까운 [GestureDetector] 조상의 onTap을 호출한다.
void _tapAncestorOf({required bool Function(Widget) find}) {
  Element? target;
  void visit(Element element) {
    if (target == null && find(element.widget)) target = element;
    element.visitChildren(visit);
  }

  _rootKey.currentContext?.visitChildElements(visit);
  target?.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is GestureDetector && widget.onTap != null) {
      widget.onTap!();
      return false;
    }
    return true;
  });
}

const _tabLabels = ['알람', '가족', '홈', '기록', '마이'];

class _StubTabPage extends StatelessWidget {
  const _StubTabPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_tabLabels[index]} 탭(W8 검증 범위 밖)')),
      bottomNavigationBar: AlarmBottomNavigation(currentIndex: index),
      body: const Center(child: Text('이 프리뷰는 가족 탭만 확인합니다')),
    );
  }
}

Future<List<Medication>> _fetchMedications(int userId, DateTime day) async {
  final date = DateTime(day.year, day.month, day.day);
  return [
    Medication(
      id: '1_$userId',
      name: '오메가3',
      dosage: '1정',
      time: '08:00',
      date: date,
      status: 'taken',
      scheduleId: 1,
      takenAt: date.add(const Duration(hours: 8, minutes: 5)),
    ),
    Medication(
      id: '2_$userId',
      name: '비타민D',
      dosage: '1정',
      time: '20:00',
      date: date,
      status: 'pending',
      scheduleId: 2,
    ),
  ];
}

// ---------------------------------------------------------------------------
// 가짜 서비스(프리뷰 전용)
// ---------------------------------------------------------------------------

FamilyGroup _group(int id, String name) {
  final now = DateTime(2026, 1, 1);
  return FamilyGroup(
    id: id,
    name: name,
    createdByUserId: 1,
    memberCount: 3,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

GroupMember _member(int userId, String name, {String role = 'MEMBER'}) {
  return GroupMember(
    id: userId,
    groupId: 1,
    userId: userId,
    userName: name,
    role: role,
    joinedAt: DateTime(2026, 1, 1),
    isActive: true,
  );
}

class _PreviewFamilyService extends FamilyService {
  final _members = [_member(1, '나', role: 'OWNER'), _member(2, '엄마'), _member(3, '아빠')];

  @override
  Future<List<FamilyGroup>> getUserGroups() async => [_group(1, '우리 가족'), _group(2, '친구들')];

  @override
  Future<List<FamilyInvitation>> getMyInvitations() async => [
        if (_scene == 'banner')
          FamilyInvitation(
            id: 5,
            groupId: 7,
            groupName: '엄마네',
            inviterUserId: 3,
            inviterName: '이모',
            inviteePhoneNumber: '010-0000-0000',
            status: 'PENDING',
            expiresAt: DateTime(2099, 1, 1),
            createdAt: DateTime(2026, 1, 1),
          ),
      ];

  @override
  Future<List<GroupMember>> getGroupMembers(int groupId) async => _members;

  @override
  Future<List<FamilyInvitation>> getGroupInvitations(int groupId) async => const [];

  @override
  Future<FamilyDashboard> getDashboard({required int groupId, DateTime? targetDate}) async {
    return FamilyDashboard(
      groupId: groupId,
      groupName: '우리 가족',
      date: targetDate ?? DateTime.now(),
      membersSummary: [
        MemberMedicationSummary(
          userId: 1,
          userName: '나',
          totalScheduled: 2,
          takenCount: 1,
          pendingCount: 1,
          missedCount: 0,
          complianceRate: 50,
        ),
        MemberMedicationSummary(
          userId: 2,
          userName: '엄마',
          totalScheduled: 3,
          takenCount: 3,
          pendingCount: 0,
          missedCount: 0,
          complianceRate: 100,
        ),
        MemberMedicationSummary(
          userId: 3,
          userName: '아빠',
          totalScheduled: 2,
          takenCount: 0,
          pendingCount: 2,
          missedCount: 0,
          complianceRate: 0,
        ),
      ],
    );
  }

  @override
  Future<FamilyGroup> createGroup(String name) async => _group(99, name);

  @override
  Future<void> sendInvitation({required int groupId, required String inviteePhoneNumber}) async {}
}

class _PreviewProfileService extends MyProfileService {
  String? _phone;

  @override
  Future<MyProfile> getMyProfile() async => MyProfile(name: '나', gender: '남', phoneNumber: _phone);

  @override
  Future<MyProfile> updateMyProfile({
    required String name,
    required String gender,
    required String phoneNumber,
  }) async {
    _phone = phoneNumber;
    return MyProfile(name: name, gender: gender, phoneNumber: phoneNumber);
  }
}

class _PreviewUserService extends UserService {
  @override
  Future<bool> isPhoneDuplicate(String phoneNumber) async => false;

  @override
  Future<UserByPhoneResponse> getUserByPhone(String phoneNumber) async {
    final names = {'+821099998888': '아빠', '+821077776666': '엄마'};
    final name = names[phoneNumber];
    return UserByPhoneResponse(exists: name != null, name: name);
  }
}
