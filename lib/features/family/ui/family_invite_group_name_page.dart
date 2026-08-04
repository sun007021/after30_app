import 'package:flutter/material.dart';
import 'package:after30/features/alarm/ui/widgets/step_header.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/features/family/ui/family_invite_existing_group_invite_page.dart';
import 'package:after30/utils/responsive.dart';

class FamilyInviteGroupNamePage extends StatefulWidget {
  const FamilyInviteGroupNamePage({super.key});

  @override
  State<FamilyInviteGroupNamePage> createState() =>
      _FamilyInviteGroupNamePageState();
}

class _FamilyInviteGroupNamePageState extends State<FamilyInviteGroupNamePage> {
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _goToNextStep() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyInviteExistingGroupInvitePage(
          groupName: groupName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
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
                    currentStep: 2,
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
                      '2. 생성할 그룹 이름 입력',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 20),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 24)),
                  Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      28,
                      0,
                      0,
                      0,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          color: const Color(0xFF111111),
                          fontWeight: FontWeight.w600,
                        ),
                        children: const [
                          TextSpan(
                            text: '·',
                            style: TextStyle(color: Color(0xFF235DFF)),
                          ),
                          TextSpan(text: '그룹 이름'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveHeight(context, 12)),
                  Padding(
                    padding: Responsive.responsivePaddingLTRB(
                      context,
                      28,
                      0,
                      28,
                      0,
                    ),
                    child: SizedBox(
                      height: Responsive.responsiveHeight(context, 66),
                      child: TextField(
                        controller: _groupNameController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _goToNextStep(),
                        decoration: _fieldDecoration(
                          context: context,
                          hintText: '최가족',
                        ),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: Responsive.responsivePaddingLTRB(
                    context,
                    48,
                    0,
                    48,
                    68,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: Responsive.responsiveHeight(context, 40),
                    child: ElevatedButton(
                      onPressed: _goToNextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF235DFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '다음',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 1),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 16),
        color: const Color(0xFF949494),
        fontWeight: FontWeight.w400,
      ),
      contentPadding: Responsive.responsivePaddingLTRB(context, 24, 16, 16, 16),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA4A4A4)),
      ),
    );
  }
}
