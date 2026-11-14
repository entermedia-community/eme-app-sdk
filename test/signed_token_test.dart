import 'dart:convert';

import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _KeyStore implements DeviceKeyStore {
  DeviceKey? key;
  @override
  Future<DeviceKey?> read() async => key;
  @override
  Future<void> save(DeviceKey key) async => this.key = key;
  @override
  Future<void> clear() async => key = null;
}

void main() {
  late _KeyStore store;
  late DateTime now;
  late SignedTokenProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _KeyStore()
      ..key = DeviceKey(
        keyId: 'k1',
        username: 'bob',
        signer: await SeedSigner.generate(),
      );
    now = DateTime(2026, 1, 1, 12);
    provider = SignedTokenProvider(keyStore: store, now: () => now);
  });

  test('sends X-tokentype signature and a signed X-token', () async {
    final h = await provider.headers();
    expect(h['X-tokentype'], 'signature');
    final t = jsonDecode(h['X-token']!) as Map<String, dynamic>;
    expect(t.keys.toSet(), {
      'username',
      'key_id',
      'timestamp',
      'nonce',
      'signature',
    });
    expect(t['username'], 'bob');
    expect(t['key_id'], 'k1');
    expect(t['timestamp'], now.millisecondsSinceEpoch.toString());
  });

  test(
    'reuses the token for 24h, then makes a new nonce and signature',
    () async {
      final first = await provider.tokenJson();
      now = now.add(const Duration(hours: 23, minutes: 59));
      expect(await provider.tokenJson(), first);
      // also reused by a fresh provider (restart) from storage
      expect(
        await SignedTokenProvider(keyStore: store, now: () => now).tokenJson(),
        first,
      );
      now = now.add(const Duration(minutes: 1));
      final renewed = await provider.tokenJson();
      expect(renewed, isNot(first));
      final a = jsonDecode(first!) as Map, b = jsonDecode(renewed!) as Map;
      expect(b['nonce'], isNot(a['nonce']));
      expect(b['signature'], isNot(a['signature']));
    },
  );

  test('no device key means no auth headers', () async {
    store.key = null;
    expect(await provider.headers(), isEmpty);
  });
}
