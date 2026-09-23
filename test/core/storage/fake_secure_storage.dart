import 'package:after30/core/storage/token_store.dart';

/// [TokenStore]의 실제 Keychain/Keystore 접근을 대체하는 메모리 기반
/// 가짜 저장소. 플랫폼 채널을 목킹하지 않고도 마이그레이션/저장 로직을
/// 검증할 수 있게 한다.
class FakeSecureStorage implements SecureStorageAdapter {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}
