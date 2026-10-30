import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the sign-in token is kept between app launches.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain on iOS, encrypted preferences on Android.
class SecureTokenStore implements TokenStore {
  static const _key = 'socialhub_access_token';
  final FlutterSecureStorage _storage;

  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// For tests: nothing is persisted.
class MemoryTokenStore implements TokenStore {
  String? _token;

  MemoryTokenStore([this._token]);

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
