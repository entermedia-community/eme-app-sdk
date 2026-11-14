import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/shared_preferences.dart';
import 'device_key_platform.dart';
import 'device_key_store.dart';

/// Builds the `X-token` / `X-tokentype: signature` headers that authenticate
/// every request to an EME server, replacing `Authorization: Bearer` and
/// `X-tokentype: entermedia`.
///
/// The token is
/// `{"username","key_id","timestamp","nonce","signature"}` where `signature`
/// signs `username\nkey_id\ntimestamp\nnonce` with this device's key. It is
/// stored and reused for [maxAge]; after that a new nonce and signature are
/// made. The private key never leaves the device keystore.
class SignedTokenProvider {
  /// The server accepts a signature for 24 hours.
  static const maxAge = Duration(hours: 24);

  static const tokenTypeHeader = 'X-tokentype';
  static const tokenHeader = 'X-token';
  static const tokenType = 'signature';

  static SignedTokenProvider instance = SignedTokenProvider();

  final DeviceKeyStore _keyStore;
  final DateTime Function() _now;

  Map<String, String>? _cached;
  Future<Map<String, String>?>? _pending;

  SignedTokenProvider({DeviceKeyStore? keyStore, DateTime Function()? now})
    : _keyStore = keyStore ?? createPlatformKeyStore(),
      _now = now ?? DateTime.now;

  /// Headers to add to a request. Empty when this device has no sign-in key
  /// (the user is signed out), so the server answers 401 instead of the app
  /// pretending to be signed in.
  Future<Map<String, String>> headers() async {
    final token = await tokenJson();
    if (token == null) return const {};
    return {tokenTypeHeader: tokenType, tokenHeader: token};
  }

  /// The JSON for `X-token`, or null when there is no device key.
  Future<String?> tokenJson() async {
    final token = await (_pending ??= _loadOrSign().whenComplete(() {
      _pending = null;
    }));
    return token == null ? null : jsonEncode(token);
  }

  /// Forgets the stored token (sign out, or the server refused it).
  Future<void> clear() async {
    _cached = null;
    await SharedPref.clearSignedToken();
  }

  Future<Map<String, String>?> _loadOrSign() async {
    try {
      final key = await _keyStore.read();
      if (key == null) {
        await clear();
        return null;
      }

      final stored = _cached ?? await _readStored();
      if (stored != null && _isUsable(stored, key)) {
        return _cached = stored;
      }

      final timestamp = _now().millisecondsSinceEpoch.toString();
      final nonce = DeviceKeyCrypto.b64url(
        List<int>.generate(24, (_) => Random.secure().nextInt(256)),
      );
      final signature = await key.signer.sign(
        DeviceKeyCrypto.loginMessage(
          username: key.username,
          keyId: key.keyId,
          timestamp: timestamp,
          nonce: nonce,
        ),
      );
      final fresh = <String, String>{
        'username': key.username,
        'key_id': key.keyId,
        'timestamp': timestamp,
        'nonce': nonce,
        'signature': signature,
      };
      _cached = fresh;
      await SharedPref.saveSignedToken(jsonEncode(fresh));
      return fresh;
    } catch (e) {
      debugPrint('[SignedTokenProvider] could not sign: $e');
      return null;
    }
  }

  /// Same user and key as this device's, and younger than [maxAge].
  bool _isUsable(Map<String, String> token, DeviceKey key) {
    if (token['username'] != key.username || token['key_id'] != key.keyId) {
      return false;
    }
    final signedAt = int.tryParse(token['timestamp'] ?? '');
    if (signedAt == null) return false;
    final age = _now().millisecondsSinceEpoch - signedAt;
    return age >= 0 && age < maxAge.inMilliseconds;
  }

  Future<Map<String, String>?> _readStored() async {
    final raw = await SharedPref.getSignedToken();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final token = {
        for (final e in decoded.entries) e.key.toString(): e.value.toString(),
      };
      const required = [
        'username',
        'key_id',
        'timestamp',
        'nonce',
        'signature',
      ];
      return required.every((k) => (token[k] ?? '').isNotEmpty) ? token : null;
    } catch (_) {
      return null;
    }
  }
}
