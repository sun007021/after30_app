import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FamilyWarnIcon extends StatelessWidget {
  const FamilyWarnIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/fam_warn.svg',
      width: 62,
      height: 62,
    );
  }
}
