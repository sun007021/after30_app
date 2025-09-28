import 'package:after30/features/family/models/invite.dart';

/// 초대 서비스 인터페이스
/// TODO: 다음달 API 연동 포인트 - 실제 API 서비스로 교체 예정
abstract class InviteService {
  /// 전화번호로 초대를 보냅니다.
  ///
  /// [phone] - E.164 포맷의 전화번호
  /// [inviterId] - 초대하는 사용자 ID
  /// [idempotencyKey] - 중복 방지를 위한 키 (선택사항)
  ///
  /// Returns: 초대 결과 (가입자/미가입자 구분)
  Future<InviteResult> inviteByPhone({
    required String phone,
    required String inviterId,
    String? idempotencyKey,
  });

  /// 사용자의 초대 목록을 가져옵니다.
  Future<List<Invite>> getInvitesByUserId(String userId);

  /// 초대 상태를 업데이트합니다.
  Future<bool> updateInviteStatus(String inviteId, InviteStatus status);

  /// 초대를 취소합니다.
  Future<bool> cancelInvite(String inviteId);
}
