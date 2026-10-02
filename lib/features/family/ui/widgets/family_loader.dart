import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

/// 가족 화면의 전체 화면 로딩 표시. iOS는 [AppActivityIndicator], Android는
/// 기존 [CircularProgressIndicator] 그대로(AppActivityIndicator의 Android
/// 분기는 기존보다 작아 외형이 달라지므로 쓰지 않는다).
class FamilyLoader extends StatelessWidget {
  const FamilyLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isCupertino(context)
          ? const AppActivityIndicator(radius: 12)
          : const CircularProgressIndicator(),
    );
  }
}
