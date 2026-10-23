import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The device's registered login key, as returned by `registerkey.json` /
/// `token.json` on the EME server.
class DeviceKey {
  final String keyId;
  final String username;
  final List<int> seed;

  const DeviceKey({
    required this.keyId,
    required this.username,
    required this.seed,
  });
}

/// Holds this device's Ed25519 private key. The server only ever sees the
/// public key; the private key never leaves the device keystore.
abstract class DeviceKeyStore {
  Future<DeviceKey?> read();
  Future<void> save(DeviceKey key);
  Future<void> clear();
}

class SecureDeviceKeyStore implements DeviceKeyStore {
  static const _keyId = 'eme_device_key_id';
  static const _username = 'eme_device_key_username';
  static const _seed = 'eme_device_key_seed';

  final FlutterSecureStorage _storage;

  const SecureDeviceKeyStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<DeviceKey?> read() async {
    final keyId = await _storage.read(key: _keyId);
    final username = await _storage.read(key: _username);
    final seed = await _storage.read(key: _seed);
    if (keyId == null || username == null || seed == null) return null;
    return DeviceKey(
      keyId: keyId,
      username: username,
      seed: base64Url.decode(base64Url.normalize(seed)),
    );
  }

  @override
  Future<void> save(DeviceKey key) async {
    await _storage.write(key: _keyId, value: key.keyId);
    await _storage.write(key: _username, value: key.username);
    await _storage.write(key: _seed, value: base64UrlEncode(key.seed));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyId);
    await _storage.delete(key: _username);
    await _storage.delete(key: _seed);
  }
}

/// Ed25519 helpers for the server's `grant_type=key` login.
class DeviceKeyCrypto {
  // ASN.1 header of an X.509 SubjectPublicKeyInfo holding an Ed25519 key.
  static const _spkiPrefix = [
    0x30,
    0x2a,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2b,
    0x65,
    0x70,
    0x03,
    0x21,
    0x00,
  ];

  static final _ed25519 = Ed25519();

  static String b64url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  /// New random 32 byte private seed.
  static Future<List<int>> newSeed() async {
    final pair = await _ed25519.newKeyPair();
    return pair.extractPrivateKeyBytes();
  }

  /// base64url X.509 public key, the `publickey` the server registers.
  static Future<String> publicKey(List<int> seed) async {
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();
    return b64url([..._spkiPrefix, ...pub.bytes]);
  }

  /// base64url signature of `username\nkey_id\ntimestamp\nnonce`
  /// (no trailing newline), as `token.json` verifies it.
  static Future<String> sign({
    required List<int> seed,
    required String username,
    required String keyId,
    required String timestamp,
    required String nonce,
  }) async {
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final message = utf8.encode('$username\n$keyId\n$timestamp\n$nonce');
    final signature = await _ed25519.sign(message, keyPair: pair);
    return b64url(signature.bytes);
  }
}
