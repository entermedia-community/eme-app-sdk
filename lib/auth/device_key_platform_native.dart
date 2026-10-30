import 'device_key_store.dart';

DeviceKeyStore createPlatformKeyStore() => const SecureDeviceKeyStore();

Future<DeviceSigner?> createPlatformSigner() => SeedSigner.generate();
