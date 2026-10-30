import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'device_key_store.dart';

// Same database, store, record and field names as the server's browserkey.js,
// so both read the same IndexedDB record: the non-extractable CryptoKey itself
// is stored, never its bytes.
const _dbName = 'emebrowserkey';
const _storeName = 'keys';
const _recordKey = 'current';

extension type _KeyRecord._(JSObject _) implements JSObject {
  external factory _KeyRecord({
    String userid,
    String keyid,
    String alg,
    web.CryptoKey privateKey,
  });

  external String get userid;
  external String get keyid;
  external String get alg;
  external web.CryptoKey get privateKey;
}

extension type _KeyPair._(JSObject _) implements JSObject {
  external web.CryptoKey get publicKey;
  external web.CryptoKey get privateKey;
}

bool _supported() => web.window.isSecureContext;

Map<String, Object?> _signAlgorithm(String alg) => alg == 'Ed25519'
    ? {'name': 'Ed25519'}
    : {'name': 'ECDSA', 'hash': 'SHA-256'};

/// Signs with a non-extractable WebCrypto key: scripts can ask the browser to
/// sign but can never read the private key.
class WebDeviceSigner implements DeviceSigner {
  @override
  final String alg;
  final web.CryptoKey privateKey;
  final web.CryptoKey? _publicKey;

  WebDeviceSigner(this.alg, this.privateKey, [this._publicKey]);

  /// Ed25519 when the browser has it, otherwise ECDSA P-256.
  static Future<WebDeviceSigner> generate() async {
    final subtle = web.window.crypto.subtle;
    final usages = ['sign', 'verify'].map((e) => e.toJS).toList().toJS;
    try {
      final pair = await subtle
          .generateKey({'name': 'Ed25519'}.jsify()!, false, usages)
          .toDart;
      final keys = pair as _KeyPair;
      return WebDeviceSigner('Ed25519', keys.privateKey, keys.publicKey);
    } catch (_) {
      final pair = await subtle
          .generateKey(
            {'name': 'ECDSA', 'namedCurve': 'P-256'}.jsify()!,
            false,
            usages,
          )
          .toDart;
      final keys = pair as _KeyPair;
      return WebDeviceSigner('P-256', keys.privateKey, keys.publicKey);
    }
  }

  @override
  Future<String> publicKey() async {
    final key = _publicKey;
    if (key == null) {
      throw StateError('The public key is only available on a new key');
    }
    final spki = await web.window.crypto.subtle
        .exportKey('spki', key)
        .toDart;
    return DeviceKeyCrypto.b64url((spki as JSArrayBuffer).toDart.asUint8List());
  }

  @override
  Future<String> sign(String message) async {
    final data = Uint8List.fromList(utf8.encode(message));
    final signature = await web.window.crypto.subtle
        .sign(_signAlgorithm(alg).jsify()!, privateKey, data.toJS)
        .toDart;
    return DeviceKeyCrypto.b64url(
      (signature as JSArrayBuffer).toDart.asUint8List(),
    );
  }
}

class IndexedDbDeviceKeyStore implements DeviceKeyStore {
  const IndexedDbDeviceKeyStore();

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_storeName);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError('IndexedDB open failed: ${request.error?.message}'),
      );
    }).toJS;
    return completer.future;
  }

  /// Runs [action] in a transaction and returns its request result once the
  /// transaction has completed.
  Future<JSAny?> _run(
    String mode,
    web.IDBRequest Function(web.IDBObjectStore store) action,
  ) async {
    final db = await _open();
    final completer = Completer<JSAny?>();
    final tx = db.transaction(_storeName.toJS, mode);
    final request = action(tx.objectStore(_storeName));
    tx.oncomplete = ((web.Event _) {
      db.close();
      completer.complete(request.result);
    }).toJS;
    tx.onerror = ((web.Event _) {
      db.close();
      completer.completeError(
        StateError('IndexedDB failed: ${tx.error?.message}'),
      );
    }).toJS;
    return completer.future;
  }

  @override
  Future<DeviceKey?> read() async {
    if (!_supported()) return null;
    final record = await _run('readonly', (s) => s.get(_recordKey.toJS));
    if (record == null || record.isUndefinedOrNull) return null;
    final rec = record as _KeyRecord;
    return DeviceKey(
      keyId: rec.keyid,
      username: rec.userid,
      signer: WebDeviceSigner(rec.alg, rec.privateKey),
    );
  }

  @override
  Future<void> save(DeviceKey key) async {
    final signer = key.signer;
    if (signer is! WebDeviceSigner) {
      throw StateError('IndexedDbDeviceKeyStore only stores WebCrypto keys');
    }
    final record = _KeyRecord(
      userid: key.username,
      keyid: key.keyId,
      alg: signer.alg,
      privateKey: signer.privateKey,
    );
    await _run('readwrite', (s) => s.put(record, _recordKey.toJS));
  }

  @override
  Future<void> clear() async {
    if (!_supported()) return;
    await _run('readwrite', (s) => s.delete(_recordKey.toJS));
  }
}

DeviceKeyStore createPlatformKeyStore() => const IndexedDbDeviceKeyStore();

/// Null when the browser has no WebCrypto/IndexedDB (plain http, private
/// windows): the code login still works, it just doesn't register a key.
Future<DeviceSigner?> createPlatformSigner() async {
  if (!_supported()) return null;
  return WebDeviceSigner.generate();
}
