import 'package:flutter/material.dart';
import 'package:after30/models/invite.dart';
import 'package:after30/services/invite_service.dart';
import 'package:after30/services/mock_invite_service.dart';

enum InviteState { idle, loading, success, error }

class InviteViewModel extends ChangeNotifier {
  InviteState _state = InviteState.idle;
  List<Invite> _recentInvites = [];
  String? _errorMessage;
  InviteResult? _lastInviteResult;

  // Getters
  InviteState get state => _state;
  List<Invite> get recentInvites => _recentInvites;
  String? get errorMessage => _errorMessage;
  InviteResult? get lastInviteResult => _lastInviteResult;

  // Mock 서비스 인스턴스 (나중에 실제 서비스로 교체)
  final InviteService _inviteService = MockInviteService();

  /// 초대 전송
  Future<void> sendInvite(String phone, String inviterId) async {
    print('🚀 InviteViewModel.sendInvite 호출');
    print('   📱 전화번호: $phone');
    print('   👤 초대자 ID: $inviterId');

    try {
      _setState(InviteState.loading);
      _errorMessage = null;

      // TODO: 다음달 API 연동 포인트 - 실제 사용자 ID 사용
      // 현재는 Mock ID 사용
      final result = await _inviteService.inviteByPhone(
        phone: phone,
        inviterId: inviterId,
      );

      print('   ✅ 초대 전송 성공');
      print('   📊 결과 타입: ${result.type}');
      print('   💬 메시지: ${result.message}');

      _lastInviteResult = result;
      _setState(InviteState.success);

      // 최근 초대 목록 갱신
      await loadRecentInvites(inviterId);
    } catch (e) {
      print('   ❌ 초대 전송 실패: $e');

      if (e is InviteError) {
        _errorMessage = e.message;
        print('   🚫 오류 타입: ${e.type}');
      } else {
        _errorMessage = '초대 전송 중 오류가 발생했습니다.';
      }

      _setState(InviteState.error);
    }
  }

  /// 최근 초대 목록 로드
  Future<void> loadRecentInvites(String userId) async {
    print('📋 InviteViewModel.loadRecentInvites 호출: $userId');

    try {
      final invites = await _inviteService.getInvitesByUserId(userId);
      _recentInvites = invites;
      print('   📊 최근 초대 목록 로드 완료: ${invites.length}개');
      notifyListeners();
    } catch (e) {
      print('   ❌ 최근 초대 목록 로드 실패: $e');
    }
  }

  /// 초대 상태 업데이트
  Future<void> updateInviteStatus(String inviteId, InviteStatus status) async {
    print('🔄 InviteViewModel.updateInviteStatus 호출');
    print('   🆔 초대 ID: $inviteId');
    print('   📊 상태: $status');

    try {
      final success = await _inviteService.updateInviteStatus(inviteId, status);
      if (success) {
        // 목록에서 해당 초대 상태 업데이트
        final index = _recentInvites.indexWhere(
          (invite) => invite.id == inviteId,
        );
        if (index != -1) {
          _recentInvites[index] = _recentInvites[index].copyWith(
            status: status,
          );
          notifyListeners();
          print('   ✅ 초대 상태 업데이트 완료');
        }
      }
    } catch (e) {
      print('   ❌ 초대 상태 업데이트 실패: $e');
    }
  }

  /// 초대 취소
  Future<void> cancelInvite(String inviteId) async {
    print('❌ InviteViewModel.cancelInvite 호출: $inviteId');

    try {
      final success = await _inviteService.cancelInvite(inviteId);
      if (success) {
        // 목록에서 해당 초대 제거
        _recentInvites.removeWhere((invite) => invite.id == inviteId);
        notifyListeners();
        print('   ✅ 초대 취소 완료');
      }
    } catch (e) {
      print('   ❌ 초대 취소 실패: $e');
    }
  }

  /// 상태 초기화
  void resetState() {
    _setState(InviteState.idle);
    _errorMessage = null;
    _lastInviteResult = null;
  }

  /// Mock 데이터 초기화 (테스트용)
  void clearMockData() {
    if (_inviteService is MockInviteService) {
      (_inviteService as MockInviteService).clearMockData();
      _recentInvites.clear();
      notifyListeners();
      print('🧹 Mock 데이터 초기화 완료');
    }
  }

  /// 상태 설정 및 알림
  void _setState(InviteState newState) {
    _state = newState;
    notifyListeners();
    print('   🔄 상태 변경: $_state');
  }

  /// 에러 메시지 설정
  void _setError(String message) {
    _errorMessage = message;
    _setState(InviteState.error);
  }
}
