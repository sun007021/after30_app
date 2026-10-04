import 'package:flutter/material.dart';
import 'package:after30/app/app_shell.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/ui/alarm_content.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/utils/responsive.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, this.content});

  /// 테스트/프리뷰용: 기본 [AlarmContent] 대신 주입 서비스가 달린 본문을 쓴다.
  /// 지정하면 [GlobalKey]를 달아 탭 재활성화 훅을 연결해야 하므로 위젯 대신
  /// 빌더가 아닌 완성된 [AlarmContent]를 받는다.
  final AlarmContent Function(Key key)? content;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  /// 알람 탭이 (다른 탭에 있다가) 다시 활성화됐을 때
  /// [AlarmContentState.onTabActivated]를 호출하기 위한 키. AppShell은 탭
  /// 상태를 유지하므로 AlarmContent의 initState는 최초 방문 때만 실행된다.
  final GlobalKey<AlarmContentState> _contentKey = GlobalKey<AlarmContentState>();

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertino(context);
    return Scaffold(
      backgroundColor: cupertino ? AppColors.groupedBackground : Colors.white,
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 0),
      body: AppShellTabActivationListener(
        tabIndex: AppShellTab.alarm,
        onActivated: () => _contentKey.currentState?.onTabActivated(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cupertino) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('등록된 약', style: AppTypography.largeTitle),
                ),
              ] else ...[
                SizedBox(height: Responsive.responsiveHeight(context, 32)),
                Padding(
                  padding: Responsive.responsivePadding(context, 24, 0),
                  child: Text(
                    '등록된 약',
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 20),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: Responsive.responsiveHeight(context, 16)),
              ],
              // 본문 리스트는 스크롤되지만, 위의 헤더 Row는 고정
              widget.content?.call(_contentKey) ?? AlarmContent(key: _contentKey),
            ],
          ),
        ),
      ),
    );
  }
}
