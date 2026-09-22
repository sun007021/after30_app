import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/utils/responsive.dart';

/// 알림 벨 아이콘만 있는 상단 바.
///
/// Android는 기존 `Container` 기반 레이아웃(마진/패딩/간격)을 그대로
/// 유지한다. iOS는 같은 벨 버튼을 [AppNavBar]의 `actions`에 실어
/// 디자인 시스템 내비게이션 바 위에 그린다(plan §6 W10 7항).
class AlarmTopBar extends StatelessWidget {
  const AlarmTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return AppNavBar(showBackButton: false, actions: [_BellButton()]);
    }
    return _AndroidAlarmTopBar();
  }
}

class _BellButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showComingSoonSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SvgPicture.asset(
          'assets/images/alarmIcon.svg',
          width: 18,
          height: 20,
        ),
      ),
    );
  }
}

Future<void> _showComingSoonSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFEBF0FF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomSafe = MediaQuery.of(ctx).viewPadding.bottom;
      return SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0).copyWith(bottom: 32 + bottomSafe),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '곧 출시될 기능입니다',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                '알림을 더 편하게 모아볼 수 있도록 준비하고 있어요.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AndroidAlarmTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: Responsive.responsiveValue(context, 8),
        bottom: Responsive.responsiveValue(context, 2),
      ),
      padding: Responsive.responsivePadding(context, 16, 0),
      child: Row(
        children: [
          const Expanded(child: Text('')),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                backgroundColor: const Color(0xFFEBF0FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      Responsive.responsiveValue(context, 16),
                    ),
                  ),
                ),
                builder: (ctx) {
                  final bottomSafe = MediaQuery.of(ctx).viewPadding.bottom;
                  return SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: true,
                    child: Padding(
                      padding:
                          Responsive.responsivePaddingLTRB(
                            ctx,
                            20,
                            20,
                            20,
                            0,
                          ).copyWith(
                            bottom:
                                Responsive.responsiveValue(ctx, 32) +
                                bottomSafe,
                          ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '곧 출시될 기능입니다',
                            style: TextStyle(
                              fontSize: Responsive.responsiveFontSize(ctx, 18),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: Responsive.responsiveHeight(ctx, 8)),
                          Text(
                            '알림을 더 편하게 모아볼 수 있도록 준비하고 있어요.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: Responsive.responsiveFontSize(ctx, 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.responsiveValue(context, 10),
                vertical: Responsive.responsiveValue(context, 6),
              ),
              child: SvgPicture.asset(
                'assets/images/alarmIcon.svg',
                width: Responsive.responsiveIconSize(context, 18),
                height: Responsive.responsiveIconSize(context, 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
