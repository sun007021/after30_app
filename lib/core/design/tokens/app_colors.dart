import 'package:flutter/material.dart';

/// 앱 전역 색상 토큰.
///
/// 기존 화면에서 하드코딩되어 흩어져 있던 색상 값을 한 곳에 정리한 것이며,
/// Android 화면의 기존 값과 동일하다(외형 변경 없음).
class AppColors {
  AppColors._();

  /// 주요 브랜드 컬러(버튼, 강조 텍스트 등).
  static const Color primary = Color(0xFF1963FF);

  /// 보조 브랜드 컬러(포인트, 아이콘 강조 등). 디자이너 확인 전까지 [primary]와
  /// 별도로 유지한다(PR 본문 "열린 질문" 참고).
  static const Color primaryAlt = Color(0xFF235DFF);

  /// tinted 배경(연한 브랜드 블루).
  static const Color primaryTint = Color(0xFFEBF0FF);

  /// iOS inset grouped 목록 배경.
  static const Color groupedBackground = Color(0xFFF2F2F7);

  /// 텍스트필드 등 옅은 회색 배경.
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  /// 본문 라벨 색상.
  static const Color label = Color(0xFF111111);

  /// 보조 라벨(placeholder, 캡션) 색상.
  static const Color secondaryLabel = Color(0xFF9CA3AF);

  /// 파괴적 액션(삭제, 탈퇴, 로그아웃) 색상.
  static const Color destructive = Color(0xFFFF3B30);

  /// 성공 상태 색상.
  static const Color success = Color(0xFF34C759);

  /// 구분선 색상.
  static const Color divider = Color(0xFFE5E5E5);

  /// 카드/시트 등 기본 배경.
  static const Color surface = Colors.white;

  /// 글래스 표면의 흰색 틴트(알파는 [GlassSurface]에서 지정).
  static const Color glassTint = Colors.white;
}
