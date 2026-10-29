import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The Firebase Auth login the EME server created for this user: the same
/// email as the EME account plus a generated password. `token.json` only
/// returns the password on the code login, so it is kept to sign in again
/// when the session is restored.
class FirebaseCredentials {
  final String email;
  final String password;

  const FirebaseCredentials({required this.email, required this.password});
}

abstract class FirebaseCredentialStore {
  Future<FirebaseCredentials?> read();
  Future<void> save(FirebaseCredentials credentials);
  Future<void> clear();
}

class SecureFirebaseCredentialStore implements FirebaseCredentialStore {
  static const _email = 'eme_firebase_email';
  static const _password = 'eme_firebase_password';

  final FlutterSecureStorage _storage;

  const SecureFirebaseCredentialStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  @override
  Future<FirebaseCredentials?> read() async {
    final email = await _storage.read(key: _email);
    final password = await _storage.read(key: _password);
    if (email == null || password == null) return null;
    return FirebaseCredentials(email: email, password: password);
  }

  @override
  Future<void> save(FirebaseCredentials credentials) async {
    await _storage.write(key: _email, value: credentials.email);
    await _storage.write(key: _password, value: credentials.password);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _email);
    await _storage.delete(key: _password);
  }
}
