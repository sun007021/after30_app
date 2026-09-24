import 'dart:convert';

import 'package:after30/core/storage/token_store.dart';
import 'package:after30/core/storage/user_store.dart';
import 'package:after30/features/family/models/group_member.dart';
import 'package:after30/features/my/data/my_profile_service.dart';

class CurrentUserResolver {
  static int? parseUserIdFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded);
      if (map is! Map) return null;

      for (final key in ['sub', 'user_id', 'id']) {
        final value = map[key];
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {}

    return null;
  }

  /// 현재 사용자의 백엔드 ID를 알아낸다(읽기 전용, 리뷰 M4).
  ///
  /// 예전에는 이 메서드가 알아낸 값을 곧바로 [UserStore]에 써 버렸다. 이
  /// 메서드는 `family_group_manage_page.dart`처럼 로그인 흐름과 무관한
  /// 화면에서도 호출되는데, 그때 이미 값을 써 버리면 이후 `SessionBootstrapper`
  /// 가 "이전 ID"를 읽을 때 이미 새 ID로 바뀐 뒤라 마이그레이션이 필요
  /// 없다고 오판하고 영구히 건너뛴다(예: 알림으로 콜드 스타트한 뒤 가족 →
  /// 그룹 관리 화면을 열었을 때). 이제 이 메서드는 값을 읽기만 하고,
  /// [UserStore]에 쓰는 것은 오직 `SessionBootstrapper`만 한다.
  static Future<int?> resolveUserId({List<GroupMember>? members}) async {
    // JWT를 최우선으로 신뢰한다. 과거에는 저장된 값(카카오 로그인 시
    // 저장된 카카오 회원 ID 등)을 먼저 신뢰했는데, 제공자마다 저장하는
    // ID가 달라(카카오 ID vs 백엔드 ID) 가족 "본인 여부" 판정이 어긋나는
    // 문제가 있었다(plan §1.5). 백엔드가 발급한 access token의
    // `sub`/`user_id`가 유일하게 신뢰할 수 있는 사용자 식별자다.
    final token = await TokenStore.getAccessToken();
    if (token != null) {
      final fromJwt = parseUserIdFromJwt(token);
      if (fromJwt != null) return fromJwt;
    }

    final stored = await UserStore.getCurrentUserId();
    final parsed = int.tryParse(stored ?? '');
    if (parsed != null) return parsed;

    if (members != null && members.isNotEmpty) {
      try {
        final profile = await MyProfileService().getMyProfile();
        final profileName = profile.name?.trim();

        for (final member in members) {
          final memberName = member.userName?.trim();
          if (profileName != null &&
              profileName.isNotEmpty &&
              memberName != null &&
              memberName.isNotEmpty &&
              profileName == memberName) {
            return member.userId;
          }
        }

        if (members.length == 1) {
          return members.first.userId;
        }
      } catch (_) {}
    }

    return null;
  }
}
