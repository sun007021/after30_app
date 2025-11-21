import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AlarmTopBar extends StatelessWidget {
  const AlarmTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomSafe),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '곧 출시될 기능입니다',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '알림을 더 편하게 모아볼 수 있도록 준비하고 있어요.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SvgPicture.asset(
                'assets/images/alarmIcon.svg',
                width: 18,
                height: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
