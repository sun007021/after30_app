import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

TextEditingValue _apply(PhoneNumberFormatter formatter, String oldText, String newText) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  late PhoneNumberFormatter formatter;

  setUp(() {
    formatter = PhoneNumberFormatter();
  });

  test('3자리 이하는 그대로 둔다', () {
    final result = _apply(formatter, '', '010');
    expect(result.text, '010');
  });

  test('4~7자리는 010-0000 형태로 하이픈을 넣는다', () {
    final result = _apply(formatter, '010', '01012');
    expect(result.text, '010-12');
  });

  test('11자리는 010-0000-0000 형태로 포맷한다', () {
    final result = _apply(formatter, '010-1234', '01012345678');
    expect(result.text, '010-1234-5678');
  });

  test('10자리(구형 번호)는 010-000-0000 형태로 포맷한다', () {
    final result = _apply(formatter, '', '0212345678');
    expect(result.text, '021-234-5678');
  });

  test('숫자가 아닌 문자는 제거된다', () {
    final result = _apply(formatter, '', '010-1234-5678');
    expect(result.text, '010-1234-5678');
  });

  test('11자리를 초과하는 입력은 잘라낸다', () {
    final result = _apply(formatter, '', '010123456789999');
    expect(result.text, '010-1234-5678');
  });
}
