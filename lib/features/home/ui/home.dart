import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/features/home/ui/home_content.dart';
import 'package:after30/features/common/navigationBar.dart';

class HomePage extends StatefulWidget {
  /// 로그인 직후 전화번호 등록 팝업을 띄우던 옛 플래그.
  ///
  /// D11(2026-09-22) 결정으로 로그인 직후에는 더 이상 전화번호 등록을
  /// 요구하지 않는다(가족 기능을 쓸 때 유도하는 방식으로 대체, W8 참고).
  /// 로그인/가입 화면(W3/W6 소유)이 이 파라미터를 계속 넘기더라도 컴파일이
  /// 깨지지 않도록 값은 무시한다.
  @Deprecated('로그인 직후 전화번호 팝업은 제거됨(D11). 가족 기능에서 유도한다.')
  final bool checkPhoneRegistration;

  const HomePage({super.key, this.checkPhoneRegistration = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;

  /// 홈 탭이 (다른 탭에 있다가) 다시 활성화됐을 때 [HomeContentState.reload]를
  /// 호출하기 위한 키(M2). AppShell은 IndexedStack으로 탭 상태를 유지하므로
  /// HomeContent의 initState는 최초 방문 때 한 번만 실행되고, 이후에는 이
  /// 훅으로만 데이터를 다시 불러올 수 있다.
  final GlobalKey<HomeContentState> _contentKey = GlobalKey<HomeContentState>();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      setState(() {
        _user = user;
      });
    } catch (error) {
      // 카카오 세션이 없는 이메일 로그인 등에서는 Kakao 사용자 정보가 없을 수 있음
      // 이 경우 앱 세션을 유지하고 홈을 그대로 보여준다.
      if (!mounted) return;
      setState(() {
        _user = null;
      });
    }
  }

  // 상단 AppBar 제거로 더 이상 사용하지 않음

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShellTabActivationListener(
        tabIndex: AppShellTab.home,
        onActivated: () => _contentKey.currentState?.reload(),
        child: HomeContent(key: _contentKey, user: _user),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 2),
    );
  }
}
