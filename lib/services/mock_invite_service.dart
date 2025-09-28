import 'package:after30/features/family/models/invite.dart';
import 'package:after30/features/family/data/invite_service.dart';
import 'package:after30/features/family/data/phone_util.dart';

/// Mock 초대 서비스 구현체
/// TODO: 다음달 API 연동 포인트 - ApiInviteService로 교체 예정
class MockInviteService implements InviteService {
  // Mock 데이터 저장소
  final Map<String, Invite> _inviteStore = {};
  final List<String> _registeredUsers = [
    '+821012345678', // 김철수
    '+821087654321', // 이영희
  ];
  final List<String> _familyMembers = [
    '+821055556666', // 박민수 (이미 가족)
  ];

  // 중복 초대 방지를 위한 최근 초대 기록
  final Map<String, DateTime> _recentInvites = {};

  @override
  Future<InviteResult> inviteByPhone({
    required String phone,
    required String inviterId,
    String? idempotencyKey,
  }) async {
    print('📞 MockInviteService.inviteByPhone 호출');
    print('   📱 전화번호: $phone');
    print('   👤 초대자 ID: $inviterId');
    print('   🔑 Idempotency Key: $idempotencyKey');

    try {
      // 1. 전화번호 정규화 및 검증
      final normalizedPhone = PhoneUtil.normalizePhoneNumber(phone);
      print('   ✅ 정규화된 번호: $normalizedPhone');

      if (!PhoneUtil.isValidPhoneNumber(normalizedPhone)) {
        print('   ❌ 유효하지 않은 전화번호');
        throw InviteError(
          type: InviteErrorType.INVALID_PHONE,
          message: '유효하지 않은 전화번호입니다.',
        );
      }

      // 2. 자기 자신 초대 금지
      if (inviterId == 'current_user_id' &&
          normalizedPhone == '+821012345678') {
        print('   ❌ 자기 자신 초대 금지');
        throw InviteError(
          type: InviteErrorType.SELF_INVITE,
          message: '자기 자신을 초대할 수 없습니다.',
        );
      }

      // 3. 이미 가족인지 확인
      if (_familyMembers.contains(normalizedPhone)) {
        print('   ❌ 이미 가족 구성원');
        throw InviteError(
          type: InviteErrorType.ALREADY_FAMILY,
          message: '이미 가족 구성원입니다.',
        );
      }

      // 4. 중복 초대 방지 (idempotencyKey 사용)
      final key =
          idempotencyKey ?? _generateIdempotencyKey(inviterId, normalizedPhone);
      if (_recentInvites.containsKey(key)) {
        final lastInviteTime = _recentInvites[key]!;
        final timeDiff = DateTime.now().difference(lastInviteTime);

        if (timeDiff.inMinutes < 5) {
          // 5분 내 중복 초대 차단
          print('   ❌ 중복 초대 (5분 내)');
          throw InviteError(
            type: InviteErrorType.DUPLICATE_INVITE,
            message: '최근에 이미 초대를 보냈습니다. 잠시 후 다시 시도해주세요.',
          );
        }
      }

      // 5. 가입 여부 판정
      final isRegistered = _registeredUsers.contains(normalizedPhone);
      print('   👥 가입 여부: ${isRegistered ? "가입자" : "미가입자"}');

      // 6. 초대 생성
      final invite = Invite(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        phone: normalizedPhone,
        inviterId: inviterId,
        createdAt: DateTime.now(),
        status: InviteStatus.SENT,
        channel: isRegistered ? InviteChannel.PUSH : InviteChannel.INSTALL_LINK,
        idempotencyKey: key,
      );

      // 7. 저장소에 저장
      _inviteStore[invite.id] = invite;
      _recentInvites[key] = DateTime.now();

      // 8. 가입자/미가입자에 따른 처리
      if (isRegistered) {
        // 가입자: 푸시 발송 시뮬레이션
        print('   📲 푸시 발송 시뮬레이션');
        print('      - FCM 토큰 조회 (시뮬레이션)');
        print('      - 초대 알림 푸시 발송 (시뮬레이션)');
        print('      - 푸시 발송 완료');

        return InviteResult(
          type: 'REGISTERED_USER',
          invite: invite,
          message: '가입자에게 앱 내 초대를 보냈습니다.',
        );
      } else {
        // 미가입자: SMS 발송 시뮬레이션
        print('   💬 SMS 발송 시뮬레이션');
        print('      - 앱 설치 링크 생성 (시뮬레이션)');
        print('      - SMS 발송 (시뮬레이션)');
        print('      - SMS 발송 완료');

        return InviteResult(
          type: 'NOT_REGISTERED',
          invite: invite,
          message: '미가입자에게 앱 설치 링크가 포함된 SMS를 보냈습니다.',
        );
      }
    } catch (e) {
      if (e is InviteError) {
        rethrow;
      }
      print('   ❌ 예상치 못한 오류: $e');
      throw InviteError(
        type: InviteErrorType.INVALID_PHONE,
        message: '초대 전송 중 오류가 발생했습니다.',
      );
    }
  }

  @override
  Future<List<Invite>> getInvitesByUserId(String userId) async {
    print('📋 MockInviteService.getInvitesByUserId 호출: $userId');

    // 해당 사용자가 보낸 초대 목록 반환
    final userInvites = _inviteStore.values
        .where((invite) => invite.inviterId == userId)
        .toList();

    // 최신순으로 정렬
    userInvites.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('   📊 사용자 초대 목록: ${userInvites.length}개');
    return userInvites;
  }

  @override
  Future<bool> updateInviteStatus(String inviteId, InviteStatus status) async {
    print('🔄 MockInviteService.updateInviteStatus 호출');
    print('   🆔 초대 ID: $inviteId');
    print('   📊 상태: $status');

    if (_inviteStore.containsKey(inviteId)) {
      final invite = _inviteStore[inviteId]!;
      _inviteStore[inviteId] = invite.copyWith(status: status);
      print('   ✅ 초대 상태 업데이트 완료');
      return true;
    }

    print('   ❌ 초대를 찾을 수 없음');
    return false;
  }

  @override
  Future<bool> cancelInvite(String inviteId) async {
    print('❌ MockInviteService.cancelInvite 호출: $inviteId');

    if (_inviteStore.containsKey(inviteId)) {
      _inviteStore.remove(inviteId);
      print('   ✅ 초대 취소 완료');
      return true;
    }

    print('   ❌ 초대를 찾을 수 없음');
    return false;
  }

  /// Idempotency Key 생성
  String _generateIdempotencyKey(String inviterId, String phone) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${inviterId}_${phone}_$timestamp';
  }

  /// Mock 데이터 초기화 (테스트용)
  void clearMockData() {
    _inviteStore.clear();
    _recentInvites.clear();
    print('🧹 Mock 데이터 초기화 완료');
  }
}
