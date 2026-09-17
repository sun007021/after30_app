import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:after30/core/design/design.dart';

/// 커서 위치를 지정하지 않는 단순 입력 시나리오(끝에 이어 타이핑)용 헬퍼.
TextEditingValue _apply(PhoneNumberFormatter formatter, String oldText, String newText) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
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
    final result = _apply(formatter, '', '0101234567');
    expect(result.text, '010-123-4567');
  });

  test('숫자가 아닌 문자는 제거된다', () {
    final result = _apply(formatter, '', '010-1234-5678');
    expect(result.text, '010-1234-5678');
  });

  test('11자리를 초과하는 입력은 잘라낸다', () {
    final result = _apply(formatter, '', '010123456789999');
    expect(result.text, '010-1234-5678');
  });

  group('서울 지역번호(02)', () {
    test('9자리는 02-XXX-XXXX 형태로 포맷한다', () {
      final result = _apply(formatter, '', '021234567');
      expect(result.text, '02-123-4567');
    });

    test('10자리는 02-XXXX-XXXX 형태로 포맷한다', () {
      final result = _apply(formatter, '', '0212345678');
      expect(result.text, '02-1234-5678');
    });
  });

  group('국가 코드 정규화', () {
    test('+82 10... 은 010...으로 정규화된다', () {
      final result = _apply(formatter, '', '+821012345678');
      expect(result.text, '010-1234-5678');
    });

    test('82...(플러스 기호 없이)도 010...으로 정규화된다', () {
      final result = _apply(formatter, '', '821012345678');
      expect(result.text, '010-1234-5678');
    });
  });

  group('커서 위치', () {
    test('중간에 숫자를 삽입해도 커서는 삽입한 숫자 바로 뒤에 남는다', () {
      // "010-134-5678"에서 커서가 3(숫자 인덱스)에 있을 때 '2'를 입력해
      // "010-1234-5678"이 되는 상황을 시뮬레이션한다.
      const oldText = '010-134-5678';
      const newText = '010-1234-5678'; // '2'가 인덱스 5 위치에 이미 삽입된 상태로 전달됨
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: 6)),
      );
      // 삽입된 '2'는 5번째 숫자(0-based 4)이므로, 포맷된 문자열에서 그 숫자
      // 바로 뒤(즉 '2' 다음)에 커서가 있어야 한다 -> "010-12|34-5678"
      expect(result.text, '010-1234-5678');
      expect(result.selection.baseOffset, result.text.indexOf('2') + 1);
    });

    test('붙여넣기 시 커서는 끝에 위치한다', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        const TextEditingValue(text: '01012345678', selection: TextSelection.collapsed(offset: 11)),
      );
      expect(result.text, '010-1234-5678');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('하이픈 바로 뒤 백스페이스', () {
    test('하이픈만 지워도 앞 숫자까지 함께 삭제된다', () {
      // "010-1234-5678"에서 두 번째 하이픈(인덱스 8) 바로 뒤에 커서를 두고
      // 백스페이스를 누르면 TextField는 하이픈만 제거한 "010-12345678"을
      // 전달한다(숫자 개수는 그대로).
      const oldText = '010-1234-5678';
      const newText = '010-12345678';
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: 9)),
        const TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: 8)),
      );
      // 하이픈 앞 숫자('4')까지 함께 지워져 "010-123-5678"이 되어야 한다.
      expect(result.text, '010-123-5678');
    });
  });
}
