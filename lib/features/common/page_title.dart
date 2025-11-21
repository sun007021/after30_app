import 'package:flutter/material.dart';

class PageTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? margin;

  const PageTitle({super.key, required this.title, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}
