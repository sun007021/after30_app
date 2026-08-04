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

  static Future<int?> resolveUserId({List<GroupMember>? members}) async {
    final stored = await UserStore.getCurrentUserId();
    final parsed = int.tryParse(stored ?? '');
    if (parsed != null) return parsed;

    final token = await TokenStore.getAccessToken();
    if (token != null) {
      final fromJwt = parseUserIdFromJwt(token);
      if (fromJwt != null) {
        await UserStore.setCurrentUserId(fromJwt.toString());
        return fromJwt;
      }
    }

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
            await UserStore.setCurrentUserId(member.userId.toString());
            return member.userId;
          }
        }

        if (members.length == 1) {
          await UserStore.setCurrentUserId(members.first.userId.toString());
          return members.first.userId;
        }
      } catch (_) {}
    }

    return null;
  }
}
