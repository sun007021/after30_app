import 'package:flutter_test/flutter_test.dart';
import 'package:after30/features/my/data/my_profile_service.dart';

void main() {
  group('MyProfile.providerDisplayNameFor', () {
    test('kakao -> 카카오톡', () {
      expect(MyProfile.providerDisplayNameFor('kakao'), '카카오톡');
    });

    test('email -> 이메일', () {
      expect(MyProfile.providerDisplayNameFor('email'), '이메일');
    });

    test('apple -> Apple(W3b에서 로그인이 추가되기 전에도 표시명은 준비돼 있다)', () {
      expect(MyProfile.providerDisplayNameFor('apple'), 'Apple');
    });

    test('대소문자를 구분하지 않는다', () {
      expect(MyProfile.providerDisplayNameFor('KAKAO'), '카카오톡');
      expect(MyProfile.providerDisplayNameFor('Email'), '이메일');
    });

    test('알 수 없거나 null이면 안전한 기본값을 반환한다', () {
      expect(MyProfile.providerDisplayNameFor(null), '알 수 없음');
      expect(MyProfile.providerDisplayNameFor(''), '알 수 없음');
      expect(MyProfile.providerDisplayNameFor('naver'), '알 수 없음');
    });
  });

  test('MyProfile.providerDisplayName 인스턴스 getter는 같은 매핑을 쓴다', () {
    final profile = MyProfile.fromJson({'provider': 'kakao'});
    expect(profile.providerDisplayName, '카카오톡');
  });
}
