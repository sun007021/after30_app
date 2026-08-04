class PhoneUtil {
  /// E.164 포맷으로 전화번호를 정규화합니다.
  /// 한국 번호는 +82로 시작하도록 변환합니다.
  static String normalizePhoneNumber(String phone) {
    // 공백, 하이픈, 괄호 제거
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // 한국 번호 처리 (010, 011, 016, 017, 018, 019)
    if (cleaned.startsWith('0') &&
        (cleaned.length == 10 || cleaned.length == 11)) {
      // 01012345678 -> +821012345678
      return '+82${cleaned.substring(1)}';
    }

    // 이미 +82로 시작하는 경우
    if (cleaned.startsWith('+82')) {
      return cleaned;
    }

    // +82로 시작하지 않는 경우 (한국 번호 가정)
    if (cleaned.startsWith('82')) {
      return '+$cleaned';
    }

    // 그 외의 경우는 그대로 반환 (국제 번호 등)
    return cleaned;
  }

  /// 전화번호 유효성을 검사합니다.
  static bool isValidPhoneNumber(String phone) {
    String normalized = normalizePhoneNumber(phone);

    // E.164 형식 검증: +[국가코드][번호]
    if (!normalized.startsWith('+')) {
      return false;
    }

    // 숫자만 남기고 길이 체크
    String digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');

    // 한국 번호: +82 + 10자리 = 총 13자리
    if (normalized.startsWith('+82') && digitsOnly.length == 12) {
      return true;
    }

    // 일반적인 국제 번호: +[국가코드] + [7-15자리]
    if (digitsOnly.length >= 7 && digitsOnly.length <= 15) {
      return true;
    }

    return false;
  }

  /// 한국 번호인지 확인합니다.
  static bool isKoreanPhoneNumber(String phone) {
    String normalized = normalizePhoneNumber(phone);
    return normalized.startsWith('+82');
  }

  /// API 조회용 로컬 전화번호 (예: 010-0000-0001)
  static String toApiPhoneQuery(String phone) {
    final normalized = normalizePhoneNumber(phone);
    if (!normalized.startsWith('+82')) {
      return phone.replaceAll(RegExp(r'[\s\(\)]'), '');
    }

    final local = '0${normalized.substring(3)}';
    if (local.length == 11) {
      return '${local.substring(0, 3)}-'
          '${local.substring(3, 7)}-'
          '${local.substring(7)}';
    }
    if (local.length == 10) {
      return '${local.substring(0, 3)}-'
          '${local.substring(3, 6)}-'
          '${local.substring(6)}';
    }
    return local;
  }

  /// 전화번호를 마스킹 처리합니다 (개인정보 보호용).
  static String maskPhoneNumber(String phone) {
    String normalized = normalizePhoneNumber(phone);

    if (normalized.startsWith('+82')) {
      // +821012345678 -> +82***123****
      return '+82***${normalized.substring(5, 8)}****';
    }

    // 일반적인 마스킹
    if (normalized.length > 4) {
      return '${normalized.substring(0, 2)}***${normalized.substring(normalized.length - 2)}';
    }

    return normalized;
  }
}
