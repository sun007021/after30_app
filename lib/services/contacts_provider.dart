import 'package:flutter/material.dart';

class ContactInfo {
  final String name;
  final String phoneNumber;

  ContactInfo({required this.name, required this.phoneNumber});
}

class ContactsProvider {
  /// 연락처 접근 권한을 요청합니다.
  static Future<bool> requestPermission() async {
    // TODO: 다음달 API 연동 포인트 - 실제 권한 요청 구현
    // 현재는 Mock으로 항상 허용된 것으로 가정

    print('🔐 연락처 권한 요청 시뮬레이션');

    // 실제 구현시:
    // var status = await Permission.contacts.request();
    // return status.isGranted;

    return true;
  }

  /// 연락처에서 전화번호를 선택하는 다이얼로그를 표시합니다.
  static Future<ContactInfo?> selectContact(BuildContext context) async {
    // TODO: 다음달 API 연동 포인트 - 실제 연락처 앱 연동
    // 현재는 Mock 데이터로 시뮬레이션

    print('📱 연락처 선택 다이얼로그 표시');

    // Mock 연락처 데이터
    final mockContacts = [
      ContactInfo(name: '김철수', phoneNumber: '01012345678'),
      ContactInfo(name: '이영희', phoneNumber: '01087654321'),
      ContactInfo(name: '박민수', phoneNumber: '01055556666'),
      ContactInfo(name: '최지영', phoneNumber: '01011112222'),
    ];

    return await showDialog<ContactInfo>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('연락처에서 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mockContacts.length,
              itemBuilder: (context, index) {
                final contact = mockContacts[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(contact.name),
                  subtitle: Text(contact.phoneNumber),
                  onTap: () {
                    Navigator.of(context).pop(contact);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  /// 권한 상태를 확인합니다.
  static Future<bool> hasPermission() async {
    // TODO: 다음달 API 연동 포인트 - 실제 권한 상태 확인
    // 현재는 Mock으로 항상 허용된 것으로 가정

    return true;
  }
}
