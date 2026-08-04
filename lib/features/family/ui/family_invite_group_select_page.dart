import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_select_page.dart';
import 'package:after30/features/family/ui/family_invite_group_name_page.dart';
import 'package:after30/utils/responsive.dart';

class FamilyInviteGroupSelectPage extends StatelessWidget {
  const FamilyInviteGroupSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: Responsive.responsivePadding(context, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: const Color(0xFF111111),
                        size: Responsive.responsiveIconSize(context, 18),
                      ),
                    ),
                  ),
                  const StepHeader(
                    currentStep: 1,
                    step1Label: '',
                    step2Label: '',
                    step3Label: '',
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 12)),
                  Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      28,
                      0,
                      0,
                      0,
                    ),
                    child: Text(
                      '1. 그룹 선택',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 20),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 32)),
                  _GroupSelectTile(
                    title: '기존 그룹 가족 초대',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const FamilyInviteExistingGroupSelectPage(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 30)),
                  _GroupSelectTile(
                    title: '새 그룹 생성하기',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FamilyInviteGroupNamePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }

}

class _GroupSelectTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _GroupSelectTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Responsive.responsivePaddingLTRB(context, 28, 0, 28, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA4A4A4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: Responsive.responsivePaddingLTRB(
                context,
                24,
                12,
                16,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 16),
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFA0A0A0),
                    size: Responsive.responsiveIconSize(context, 34),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
