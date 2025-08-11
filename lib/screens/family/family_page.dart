import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:after30/viewmodels/invite_view_model.dart';
import 'package:after30/services/contacts_provider.dart';
import 'package:after30/services/phone_util.dart';
import 'package:after30/models/invite.dart';
import 'package:after30/widgets/common/navigationBar.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  void initState() {
    super.initState();
    // 페이지 진입시 최근 초대 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InviteViewModel>().loadRecentInvites('current_user_id');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가족'),
        backgroundColor: Colors.yellow[100],
      ),
      body: Consumer<InviteViewModel>(
        builder: (context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 초대하기 버튼
                _buildInviteButton(context, viewModel),
                const SizedBox(height: 24),

                // 최근 초대 목록
                _buildRecentInvitesList(viewModel),

                // 상태별 UI
                if (viewModel.state == InviteState.loading)
                  const Center(child: CircularProgressIndicator()),

                if (viewModel.state == InviteState.error &&
                    viewModel.errorMessage != null)
                  _buildErrorMessage(viewModel.errorMessage!),

                if (viewModel.state == InviteState.success &&
                    viewModel.lastInviteResult != null)
                  _buildSuccessMessage(viewModel.lastInviteResult!),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }

  /// 초대하기 버튼
  Widget _buildInviteButton(BuildContext context, InviteViewModel viewModel) {
    return ElevatedButton.icon(
      onPressed: viewModel.state == InviteState.loading
          ? null
          : () => _showInviteDialog(context, viewModel),
      icon: const Icon(Icons.person_add),
      label: const Text('초대하기'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow[600],
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 최근 초대 목록
  Widget _buildRecentInvitesList(InviteViewModel viewModel) {
    if (viewModel.recentInvites.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '아직 보낸 초대가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 전송한 초대',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: viewModel.recentInvites.length,
          itemBuilder: (context, index) {
            final invite = viewModel.recentInvites[index];
            return _buildInviteItem(invite, viewModel);
          },
        ),
      ],
    );
  }

  /// 초대 아이템
  Widget _buildInviteItem(Invite invite, InviteViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          invite.channel == InviteChannel.PUSH
              ? Icons.notifications
              : Icons.sms,
          color: invite.channel == InviteChannel.PUSH
              ? Colors.blue
              : Colors.green,
        ),
        title: Text(PhoneUtil.maskPhoneNumber(invite.phone)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('채널: ${invite.channel == InviteChannel.PUSH ? "푸시" : "SMS"}'),
            Text('상태: ${_getStatusText(invite.status)}'),
            Text('전송시간: ${_formatDateTime(invite.createdAt)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'cancel') {
              viewModel.cancelInvite(invite.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'cancel', child: Text('취소')),
          ],
        ),
      ),
    );
  }

  /// 에러 메시지
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.red[50]!,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[600]!),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  /// 성공 메시지
  Widget _buildSuccessMessage(InviteResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.green[50]!,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600]!),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// 초대 다이얼로그 표시
  Future<void> _showInviteDialog(
    BuildContext context,
    InviteViewModel viewModel,
  ) async {
    // 연락처 권한 확인
    final hasPermission = await ContactsProvider.hasPermission();
    if (!hasPermission) {
      final granted = await ContactsProvider.requestPermission();
      if (!granted) {
        _showSnackBar(context, '연락처 접근 권한이 필요합니다.');
        return;
      }
    }

    // 연락처에서 선택
    final contact = await ContactsProvider.selectContact(context);
    if (contact == null) return;

    // 전화번호 정규화
    final normalizedPhone = PhoneUtil.normalizePhoneNumber(contact.phoneNumber);

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초대 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이름: ${contact.name}'),
            Text('전화번호: $normalizedPhone'),
            const SizedBox(height: 16),
            const Text('이 번호로 초대를 보내시겠습니까?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('보내기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 초대 전송
      await viewModel.sendInvite(normalizedPhone, 'current_user_id');

      // 성공/실패 메시지 표시
      if (viewModel.state == InviteState.success) {
        _showSnackBar(context, viewModel.lastInviteResult!.message);
      } else if (viewModel.state == InviteState.error) {
        _showSnackBar(context, viewModel.errorMessage ?? '초대 전송에 실패했습니다.');
      }
    }
  }

  /// 스낵바 표시
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// 상태 텍스트 변환
  String _getStatusText(InviteStatus status) {
    switch (status) {
      case InviteStatus.SENT:
        return '전송됨';
      case InviteStatus.ACCEPTED:
        return '수락됨';
      case InviteStatus.DECLINED:
        return '거절됨';
      case InviteStatus.EXPIRED:
        return '만료됨';
    }
  }

  /// 날짜 시간 포맷
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
