import 'package:flutter/services.dart';

/// 한국 휴대폰 번호(010-0000-0000)를 입력하는 동안 자동으로 하이픈을
/// 붙여주는 [TextInputFormatter].
///
/// 저장/전송용 정규화(E.164 등)는 `phone_util.dart`의 [PhoneUtil]이
/// 담당하므로 이 포매터는 표시용 하이픈 삽입만 책임진다.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _format(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _format(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    // 010-0000-0000(11자리) / 010-000-0000(10자리) 두 형태를 지원한다.
    if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    final midEnd = digits.length == 11 ? 7 : 6;
    return '${digits.substring(0, 3)}-${digits.substring(3, midEnd)}-${digits.substring(midEnd)}';
  }
}
