import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:after30/services/invite_view_model.dart';
import 'package:after30/features/family/data/contacts_provider.dart';
import 'package:after30/features/family/data/phone_util.dart';
import 'package:after30/features/family/models/invite.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:after30/utils/responsive.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  @override
  void initState() {
    super.initState();
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
            padding: Responsive.responsivePadding(context, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInviteButton(context, viewModel),
                SizedBox(height: Responsive.responsiveHeight(context, 24)),
                _buildRecentInvitesList(context, viewModel),
                if (viewModel.state == InviteState.loading)
                  const Center(child: CircularProgressIndicator()),
                if (viewModel.state == InviteState.error &&
                    viewModel.errorMessage != null)
                  _buildErrorMessage(context, viewModel.errorMessage!),
                if (viewModel.state == InviteState.success &&
                    viewModel.lastInviteResult != null)
                  _buildSuccessMessage(context, viewModel.lastInviteResult!),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }

  Widget _buildInviteButton(BuildContext context, InviteViewModel viewModel) {
    return ElevatedButton.icon(
      onPressed: viewModel.state == InviteState.loading
          ? null
          : () => _showInviteDialog(context, viewModel),
      icon: Icon(
        Icons.person_add,
        size: Responsive.responsiveIconSize(context, 24),
      ),
      label: Text(
        '초대하기',
        style: TextStyle(fontSize: Responsive.responsiveFontSize(context, 16)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow[600],
        foregroundColor: Colors.black87,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.responsiveValue(context, 16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            Responsive.responsiveValue(context, 12),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentInvitesList(
    BuildContext context,
    InviteViewModel viewModel,
  ) {
    if (viewModel.recentInvites.isEmpty) {
      return Card(
        child: Padding(
          padding: Responsive.responsivePadding(context, 16, 0),
          child: Text(
            '아직 보낸 초대가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: Responsive.responsiveFontSize(context, 14),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 전송한 초대',
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: Responsive.responsiveHeight(context, 12)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: viewModel.recentInvites.length,
          itemBuilder: (context, index) {
            final invite = viewModel.recentInvites[index];
            return _buildInviteItem(context, invite, viewModel);
          },
        ),
      ],
    );
  }

  Widget _buildInviteItem(
    BuildContext context,
    Invite invite,
    InviteViewModel viewModel,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: Responsive.responsiveValue(context, 8)),
      child: ListTile(
        leading: Icon(
          invite.channel == InviteChannel.PUSH
              ? Icons.notifications
              : Icons.sms,
          color: invite.channel == InviteChannel.PUSH
              ? Colors.blue
              : Colors.green,
          size: Responsive.responsiveIconSize(context, 24),
        ),
        title: Text(
          PhoneUtil.maskPhoneNumber(invite.phone),
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 16),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '채널: ${invite.channel == InviteChannel.PUSH ? "푸시" : "SMS"}',
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 14),
              ),
            ),
            Text(
              '상태: ${_getStatusText(invite.status)}',
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 14),
              ),
            ),
            Text(
              '전송시간: ${_formatDateTime(invite.createdAt)}',
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 14),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'cancel') {
              viewModel.cancelInvite(invite.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'cancel', child: Text('취소')),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    return Container(
      padding: Responsive.responsivePadding(context, 16, 0),
      margin: EdgeInsets.only(top: Responsive.responsiveValue(context, 16)),
      decoration: BoxDecoration(
        color: Colors.red[50]!,
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 8),
        ),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: Colors.red[600]!,
            size: Responsive.responsiveIconSize(context, 24),
          ),
          SizedBox(width: Responsive.responsiveWidth(context, 12)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: Responsive.responsiveFontSize(context, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(BuildContext context, InviteResult result) {
    return Container(
      padding: Responsive.responsivePadding(context, 16, 0),
      margin: EdgeInsets.only(top: Responsive.responsiveValue(context, 16)),
      decoration: BoxDecoration(
        color: Colors.green[50]!,
        borderRadius: BorderRadius.circular(
          Responsive.responsiveValue(context, 8),
        ),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600]!,
            size: Responsive.responsiveIconSize(context, 24),
          ),
          SizedBox(width: Responsive.responsiveWidth(context, 12)),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: Colors.green[700],
                fontSize: Responsive.responsiveFontSize(context, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteDialog(
    BuildContext context,
    InviteViewModel viewModel,
  ) async {
    final hasPermission = await ContactsProvider.hasPermission();
    if (!hasPermission) {
      final granted = await ContactsProvider.requestPermission();
      if (!granted) {
        _showSnackBar(context, '연락처 접근 권한이 필요합니다.');
        return;
      }
    }

    final contact = await ContactsProvider.selectContact(context);
    if (contact == null) return;

    final normalizedPhone = PhoneUtil.normalizePhoneNumber(contact.phoneNumber);

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
      await viewModel.sendInvite(normalizedPhone, 'current_user_id');
      if (viewModel.state == InviteState.success) {
        _showSnackBar(context, viewModel.lastInviteResult!.message);
      } else if (viewModel.state == InviteState.error) {
        _showSnackBar(context, viewModel.errorMessage ?? '초대 전송에 실패했습니다.');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
