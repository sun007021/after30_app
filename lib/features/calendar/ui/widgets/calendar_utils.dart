/// 날짜를 키로 변환 (시간 정보 제거)
DateTime dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// 요일 번호를 한글로 변환
String weekdayKor(int weekday) {
  const arr = ['월', '화', '수', '목', '금', '토', '일'];
  return arr[(weekday + 6) % 7];
}

/// 시간 문자열을 한글 형식으로 포맷팅 (예: "알람 09:30")
String formatKorTime(String hhmm) {
  final parts = hhmm.split(':');
  final int h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final int m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return '알람 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// DateTime을 KST 기준 HH:mm 형식으로 포맷팅
String formatHHmmKST(DateTime dt) {
  final kst = dt.add(const Duration(hours: 9));
  return '${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')}';
}



