/// 날짜를 한국어 형식으로 포맷팅 (예: "12/25 (수)")
String formatKoreanDate(DateTime d) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = days[(d.weekday + 6) % 7];
  return '${d.month}/${d.day} ($weekday)';
}

/// DateTime을 YYYYMMDD 형식 문자열로 변환
String yyyymmdd(DateTime d) {
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// 시간 문자열을 한글 형식으로 포맷팅 (예: "알람 09:30")
String formatKoreanTime(String hhmmss) {
  final parts = hhmmss.split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '알람 $hh:$mm';
}

/// DateTime을 KST 기준 HH:mm 형식으로 포맷팅
String formatHHmm(DateTime dt) {
  // 서버에서 오는 완료 시간이 UTC 기준이므로 KST(+9)로 보정 후 24시간제로 변환
  final adjusted = dt.add(const Duration(hours: 9));
  final hh = adjusted.hour.toString().padLeft(2, '0');
  final mm = adjusted.minute.toString().padLeft(2, '0');
  return '알람 $hh:$mm';
}
