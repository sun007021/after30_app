import 'package:flutter/material.dart';
import 'package:after30/features/common/navigationBar.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:after30/features/common/page_title.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key});

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  String? _nickname;
  String? _email;
  String? _imageUrl;
  bool _marketingConsent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _nickname = args['nickname'] as String?;
      _imageUrl = args['imageUrl'] as String?;
      _marketingConsent = (args['allowMarketing'] as bool?) ?? false;
    }
    _loadKakaoAccount();
  }

  Future<void> _loadKakaoAccount() async {
    try {
      final user = await UserApi.instance.me();
      final account = user.kakaoAccount;
      if (!mounted) return;
      setState(() {
        _nickname = _nickname ?? account?.profile?.nickname ?? '사용자';
        _imageUrl = _imageUrl ?? account?.profile?.profileImageUrl;
        _email = account?.email;
      });
    } catch (_) {
      // 권한이 없거나 로그인 안 된 경우: 전달받은 값만 사용
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.arrow_back_ios_new, size: 22),
                      ),
                      const SizedBox(width: 8),
                      const PageTitle(
                        title: '내 정보 조회',
                        margin: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 기본 정보 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('기본 정보'),
                      const Divider(height: 24),
                      _InfoRow(label: '성명', value: _nickname ?? '-'),
                      const SizedBox(height: 16),
                      _InfoRow(label: '이메일 주소', value: _email ?? '-'),
                      const SizedBox(height: 16),
                      const _InfoRow(label: '연동된 SSO', value: '카카오톡'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 기타 정보 카드
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('기타 정보'),
                      const Divider(height: 24),
                      _InfoRow(
                        label: '광고 정보 수신 동의',
                        value: _marketingConsent ? '동의' : '미동의',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 4),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}

// (삭제됨) 우측 화살표 행은 더 이상 사용하지 않습니다.
