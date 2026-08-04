import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:after30/utils/responsive.dart';

class MyInfoHeader extends StatelessWidget {
  final String actionLabel;
  final bool actionFilled;
  final VoidCallback onBack;
  final VoidCallback onAction;

  const MyInfoHeader({
    super.key,
    required this.actionLabel,
    required this.actionFilled,
    required this.onBack,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          child: Icon(
            Icons.arrow_back_ios_new,
            size: Responsive.responsiveIconSize(context, 22),
          ),
        ),
        SizedBox(width: Responsive.responsiveWidth(context, 8)),
        Expanded(
          child: Text(
            '내 정보 조회',
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 18),
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        _MyInfoActionButton(
          label: actionLabel,
          filled: actionFilled,
          onTap: onAction,
        ),
      ],
    );
  }
}

class _MyInfoActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MyInfoActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: Responsive.responsivePaddingLTRB(context, 10, 5, 10, 5),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF235DFF) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: filled ? const Color(0xFF235DFF) : const Color(0xFFCAD8FF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              filled
                  ? 'assets/images/mypage_edit_done.svg'
                  : 'assets/images/mypage_edit.svg',
              width: Responsive.responsiveIconSize(context, 14),
              height: Responsive.responsiveIconSize(context, 14),
            ),
            SizedBox(width: Responsive.responsiveWidth(context, 8)),
            Text(
              label,
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 12),
                fontWeight: FontWeight.w500,
                color: filled ? Colors.white : const Color(0xFF235DFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyInfoSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const MyInfoSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: Responsive.responsivePaddingLTRB(context, 10, 15, 10, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 13),
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 5)),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
          Padding(
            padding: Responsive.responsivePaddingLTRB(context, 2, 10, 2, 0),
            child: child,
          ),
        ],
      ),
    );
  }
}

class MyInfoReadRow extends StatelessWidget {
  final String label;
  final String value;

  const MyInfoReadRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 12),
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 12),
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class MyInfoFieldLabel extends StatelessWidget {
  final String label;

  const MyInfoFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: Responsive.responsiveFontSize(context, 12),
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
    );
  }
}

class MyInfoTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType? keyboardType;

  const MyInfoTextField({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Responsive.responsivePaddingLTRB(context, 10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFD8D8D8)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 12),
          fontWeight: FontWeight.w400,
          color: readOnly ? Colors.black54 : Colors.black,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class MyInfoGenderSelector extends StatelessWidget {
  final String? selectedGender;
  final ValueChanged<String> onChanged;

  const MyInfoGenderSelector({
    super.key,
    required this.selectedGender,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GenderOption(
          label: '남',
          selected: selectedGender == '남',
          onTap: () => onChanged('남'),
        ),
        SizedBox(width: Responsive.responsiveWidth(context, 50)),
        _GenderOption(
          label: '여',
          selected: selectedGender == '여',
          onTap: () => onChanged('여'),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF235DFF) : const Color(0xFFD8D8D8),
                width: selected ? 5 : 1.5,
              ),
            ),
          ),
          SizedBox(width: Responsive.responsiveWidth(context, 8)),
          Text(
            label,
            style: TextStyle(
              fontSize: Responsive.responsiveFontSize(context, 12),
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class MyInfoMarketingSwitchRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const MyInfoMarketingSwitchRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '광고 정보 수신 동의',
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 12),
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF235DFF),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[300],
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
