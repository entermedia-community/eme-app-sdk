import 'dart:convert';

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
        name: 'Test Server',
        description: 'Test Description',
        category: ServerCategoryModel(
          id: 'software_tools',
          name: 'Software Tools',
        ),
      );
      expect(server.id, 'srv_test');
      expect(server.category.name, 'Software Tools');
      expect(server.categoryLabel, 'Software Tools');
      expect(server.displayInitials, 'TS');

      final serverJson = server.toJson();
      final fromJson = ServerModel.fromJson(serverJson);
      expect(fromJson.id, 'srv_test');
      expect(fromJson.category.name, 'Software Tools');
      expect(fromJson.categoryLabel, 'Software Tools');
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

    test('ChatMessage parses form with agentcontextvalues properly', () {
      final rawJson = {
        'messageid': 'msg_form_1',
        'channel': 'ch_1',
        'userid': 'bot_1',
        'date': DateTime.now().toIso8601String(),
        'agentcontextvalues': {
          'messagerendertype': 'form',
          'form': [
            {'type': 'text', 'name': 'name', 'label': 'Name'},
            {
              'type': 'bool',
              'name': 'agree',
              'label': 'Agree to terms',
              'value': true,
              'readOnly': false,
            },
            {
              'type': 'select',
              'name': 'role',
              'label': 'Role',
              'value': 'admin',
              'options': [
                {'value': 'admin', 'label': 'Administrator'},
                {'value': 'user', 'label': 'Standard User'},
              ],
            },
          ],
        },
      };

      final msg = ChatMessage.fromJson(rawJson);
      expect(msg.messageRenderType, MessageRenderType.form);
      expect(msg.formFields.length, 3);
      expect(msg.formFields[0].name, 'name');
      expect(msg.formFields[0].label, 'Name');
      expect(msg.formFields[0].type, FormFieldType.text);
      expect(msg.formFields[1].name, 'agree');
      expect(msg.formFields[1].value, true);
      expect(msg.formFields[1].readOnly, false);
      expect(msg.formFields[2].name, 'role');
      expect(msg.formFields[2].type, FormFieldType.select);
      expect(msg.formFields[2].options.length, 2);
      expect(msg.formFields[2].options[0].value, 'admin');
      expect(msg.formFields[2].options[0].label, 'Administrator');
      expect(msg.formFields[2].toJson()['options'].length, 2);
    });

    test(
      'ChatMessage parses delta from message JSON string containing ops key',
      () {
        final rawJson = {
          'messageid': 'msg_delta_1',
          'channel': 'ch_1',
          'userid': 'bot_1',
          'date': DateTime.now().toIso8601String(),
          'message': jsonEncode({
            'ops': [
              {'insert': 'Welcome to the server!\n'},
              {
                'attributes': {'bold': true},
                'insert': 'How can I help you today?',
              },
            ],
          }),
        };

        final msg = ChatMessage.fromJson(rawJson);
        expect(msg.messageRenderType, MessageRenderType.delta);
        expect(msg.deltaOps.length, 2);
        expect(msg.deltaOps[0]['insert'], 'Welcome to the server!\n');
        expect(msg.deltaOps[1]['attributes']['bold'], true);
        expect(msg.text, 'Welcome to the server!\nHow can I help you today?');
        expect(msg.formFields, isEmpty);
      },
    );

    test(
      'ChatMessage parses form from message JSON string containing form key',
      () {
        final rawJson = {
          'messageid': 'msg_form_2',
          'channel': 'ch_1',
          'userid': 'bot_1',
          'date': DateTime.now().toIso8601String(),
          'message': jsonEncode({
            'form': [
              {'type': 'text', 'name': 'search_term', 'label': 'Search...'},
              {
                'type': 'select',
                'name': 'category',
                'label': 'Category',
                'value': 'all',
                'options': [
                  {'value': 'all', 'label': 'All'},
                  {'value': 'docs', 'label': 'Documents'},
                ],
              },
            ],
          }),
        };

        final msg = ChatMessage.fromJson(rawJson);
        expect(msg.messageRenderType, MessageRenderType.form);
        expect(msg.formFields.length, 2);
        expect(msg.formFields[0].name, 'search_term');
        expect(msg.formFields[0].type, FormFieldType.text);
        expect(msg.formFields[1].name, 'category');
        expect(msg.formFields[1].type, FormFieldType.select);
        expect(msg.formFields[1].options.length, 2);
        expect(msg.interactive, true);
      },
    );

    test('ChatMessage parses both ops and form from message JSON string', () {
      final rawJson = {
        'messageid': 'msg_combo_1',
        'channel': 'ch_1',
        'userid': 'bot_1',
        'date': DateTime.now().toIso8601String(),
        'message': jsonEncode({
          'ops': [
            {
              'attributes': {'header': 3},
              'insert': 'Search Media',
            },
            {'insert': '\n'},
          ],
          'formAttr': {'action': '/search', 'method': 'post'},
          'form': [
            {'type': 'text', 'name': 'context_query', 'label': 'Search...'},
          ],
        }),
      };

      final msg = ChatMessage.fromJson(rawJson);
      expect(msg.messageRenderType, MessageRenderType.form);
      expect(msg.deltaOps.length, 2);
      expect(msg.formFields.length, 1);
      expect(msg.formFields.first.name, 'context_query');
      expect(msg.text, 'Search Media\n');

      final copied = msg.copyWith(userId: 'other_user');
      expect(copied.userId, 'other_user');
      expect(copied.deltaOps.length, 2);
      expect(copied.formFields.length, 1);
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
