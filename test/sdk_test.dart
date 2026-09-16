import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EME App SDK Tests', () {
    test('Models and serialization work properly', () {
      final catalog = ProductMessageModel.sampleCatalog;
      expect(catalog.isNotEmpty, true);

      final ecom = catalog.first;
      final json = ecom.toJson();
      final reconstructed = ProductMessageModel.fromJson(json);
      expect(reconstructed.id, ecom.id);
      expect(reconstructed.title, ecom.title);
      expect(reconstructed.formattedPrice, ecom.formattedPrice);
    });

    test('Server and Profile models instantiate properly', () {
      const server = ServerModel(
        id: 'srv_test',
        title: 'Test Node',
        description: 'Test Description',
        category: ServerCategory.softwareTools,
        tags: ['Tools'],
        iconData: Icons.hub,
      );
      expect(server.id, 'srv_test');
      expect(server.category.label, 'Software Tools');

      final serverJson = server.toJson();
      final fromJson = ServerModel.fromJson(serverJson);
      expect(fromJson.id, 'srv_test');
      expect(fromJson.category, ServerCategory.softwareTools);
    });

    test('Riverpod providers initialize correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final serverState = container.read(serverProvider);
      expect(serverState.servers.isNotEmpty, true);

      final profileState = container.read(emeProfileProvider);
      expect(profileState.profiles.isNotEmpty, true);

      final userProfile = container.read(profileProvider);
      expect(userProfile.name, isNotEmpty);

      await container.read(authProvider.notifier).checkAuthSession();
      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.unauthenticated);
    });
  });
}
