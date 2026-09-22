import 'package:flutter/services.dart';

/// 한국 전화번호(휴대폰 010-0000-0000, 서울 지역번호 02-000-0000/
/// 02-0000-0000)를 입력하는 동안 자동으로 하이픈을 붙여주는
/// [TextInputFormatter].
///
/// 저장/전송용 정규화(E.164 등)는 `phone_util.dart`의 [PhoneUtil]이
/// 담당하므로 이 포매터는 표시용 하이픈 삽입과 다음을 책임진다.
/// - 커서 위치를 숫자 개수 기준으로 유지(중간 수정 시 커서가 끝으로
///   튀지 않음)
/// - 하이픈 바로 뒤에서 백스페이스를 누르면 하이픈 앞 숫자까지 함께 삭제
/// - `+82`/`82` 국가 코드를 `0`으로 정규화(`+82 10...` → `010...`)
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final isDeletion = newValue.text.length < oldValue.text.length;
    final oldDigits = _digitsOnly(oldValue.text);

    // 국가 코드(+82/82) 정규화: 콜백 안에서는 아직 하이픈이 붙기 전이므로
    // 순수 숫자만 남긴 뒤 앞부분이 82로 시작하면 0으로 치환한다.
    var digits = _digitsOnly(newValue.text);
    if (digits.startsWith('82') && digits.length > 2) {
      digits = '0${digits.substring(2)}';
    }

    var cursorDigitIndex = _digitsBefore(newValue.text, newValue.selection.end);

    // 하이픈 바로 뒤에서 백스페이스: 삭제인데도 숫자 개수가 그대로라면
    // 하이픈만 지워진 것이므로, 하이픈 앞의 숫자까지 함께 지운다.
    if (isDeletion && digits.length == oldDigits.length && cursorDigitIndex > 0) {
      digits = digits.substring(0, cursorDigitIndex - 1) + digits.substring(cursorDigitIndex);
      cursorDigitIndex -= 1;
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
      if (cursorDigitIndex > 11) cursorDigitIndex = 11;
    }

    final formatted = _format(digits);
    final caretOffset = _offsetForDigitIndex(formatted, cursorDigitIndex);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }

  static String _digitsOnly(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

  static bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  /// [text]에서 [index] 앞에 있는 숫자 문자의 개수.
  static int _digitsBefore(String text, int index) {
    final end = index.clamp(0, text.length);
    var count = 0;
    for (var i = 0; i < end; i++) {
      if (_isDigit(text[i])) count++;
    }
    return count;
  }

  /// [formatted] 문자열에서 [digitIndex]번째 숫자 바로 뒤의 오프셋.
  static int _offsetForDigitIndex(String formatted, int digitIndex) {
    if (digitIndex <= 0) return 0;
    var seen = 0;
    for (var pos = 0; pos < formatted.length; pos++) {
      if (_isDigit(formatted[pos])) {
        seen++;
        if (seen >= digitIndex) return pos + 1;
      }
    }
    return formatted.length;
  }

  static String _format(String digits) {
    // 서울 지역번호(02): 02-XXX-XXXX(9자리) / 02-XXXX-XXXX(10자리 이상).
    if (digits.startsWith('02')) {
      final rest = digits.substring(2);
      if (rest.isEmpty) return digits;
      final midEnd = rest.length >= 8 ? 4 : 3;
      if (rest.length <= midEnd) return '02-$rest';
      return '02-${rest.substring(0, midEnd)}-${rest.substring(midEnd)}';
    }

    if (digits.length <= 3) {
      return digits;
    }
    // 010-0000-0000(11자리) / 010-000-0000(10자리, 구형) 두 형태를 지원한다.
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    final midEnd = digits.length >= 11 ? 7 : 6;
    return '${digits.substring(0, 3)}-${digits.substring(3, midEnd)}-${digits.substring(midEnd)}';
  }
}
