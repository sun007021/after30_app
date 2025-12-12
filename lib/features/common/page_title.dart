import 'package:flutter/material.dart';
import 'package:after30/utils/responsive.dart';

class PageTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? margin;

  const PageTitle({super.key, required this.title, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ?? Responsive.responsivePaddingLTRB(context, 20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.responsiveFontSize(context, 20),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
