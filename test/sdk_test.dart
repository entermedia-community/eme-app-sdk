import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'auth_service_test.dart';

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
        name: 'Test Node',
        description: 'Test Description',
        category: 'Software Tools',
      );
      expect(server.id, 'srv_test');
      expect(server.category, 'Software Tools');
      expect(server.displayInitials, 'TN');

      final serverJson = server.toJson();
      final fromJson = ServerModel.fromJson(serverJson);
      expect(fromJson.id, 'srv_test');
      expect(fromJson.category, 'Software Tools');
    });

    test('ChatMessage and MessageRenderType work properly', () {
      final textMsg = ChatMessage(
        messageId: 'msg_1',
        channel: 'general',
        userId: 'user_1',
        message: 'Hello World',
        createdAt: DateTime.now(),
      );
      expect(textMsg.messageRenderType, MessageRenderType.text);
      expect(textMsg.text, 'Hello World');

      final product = ProductMessageModel.sampleCatalog.first;
      final productMsg = ChatMessage(
        messageId: 'msg_2',
        channel: 'general',
        userId: 'user_2',
        message: 'Check this product',
        messageType: 'product',
        product: product,
        createdAt: DateTime.now(),
      );
      expect(productMsg.messageRenderType, MessageRenderType.product);
      expect(productMsg.product?.id, product.id);

      final json = productMsg.toJson();
      final reconstructed = ChatMessage.fromJson(json);
      expect(reconstructed.messageId, 'msg_2');
      expect(reconstructed.messageRenderType, MessageRenderType.product);
      expect(reconstructed.product?.title, product.title);

      const chatThread = ChatModel(
        channelId: 'chat_1',
        username: 'Alice',
        displayName: 'Developer',
        lastMessage: 'Ready for review',
        time: '10:00 AM',
        avatarColor: Color(0xFF2563EB),
      );
      expect(chatThread.username, 'Alice');
      final chatJson = chatThread.toJson();
      expect(ChatModel.fromJson(chatJson).username, 'Alice');
    });

    test(
      'Riverpod providers initialize correctly and searchUsers works',
      () async {
        final mockDio = createMockAuthDio();
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(AuthService(dio: mockDio)),
            apiServiceProvider.overrideWithValue(ApiService(dio: mockDio)),
          ],
        );
        addTearDown(container.dispose);

        await container.read(serverProvider.notifier).loadServersFromApi();
        final serverState = container.read(serverProvider);
        expect(serverState.servers.isNotEmpty, true);
        expect(serverState.servers.first.id, 'srv_mock_1');

        await container.read(emeProfileProvider.notifier).loadUsers();
        final profileState = container.read(emeProfileProvider);
        expect(profileState.profiles.isNotEmpty, true);

        await container.read(profileProvider.notifier).loadProfileFromApi();
        final userProfile = container.read(profileProvider);
        expect(userProfile.name, isNotEmpty);

        await container.read(authProvider.notifier).checkAuthSession();
        final authState = container.read(authProvider);
        expect(authState.status, AuthStatus.unauthenticated);

        // Test searching users
        await container.read(emeProfileProvider.notifier).searchUsers('admin');
        // Wait for debounce timer
        await Future.delayed(const Duration(milliseconds: 350));
        final searchedProfiles = container
            .read(emeProfileProvider)
            .filteredProfiles;
        expect(searchedProfiles.isNotEmpty, true);
        expect(searchedProfiles.first.username, 'admin');
        expect(searchedProfiles.first.name, 'The Administrator');
        expect(searchedProfiles.first.avatarUrl, contains('jefferson-santos'));
      },
    );
  });
}
