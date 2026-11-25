import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('form fields', () {
    test('parses date/time/datetime/textarea and their aliases', () {
      FormFieldType t(String name) => FormFieldType.fromName(name);
      expect(t('date'), FormFieldType.date);
      expect(t('time'), FormFieldType.time);
      expect(t('datetime-local'), FormFieldType.datetime);
      expect(t('datetime'), FormFieldType.datetime);
      expect(t('textarea'), FormFieldType.textarea);
      expect(t('multiline'), FormFieldType.textarea);
      expect(t('paragraph'), FormFieldType.textarea);
      expect(t('somethingelse'), FormFieldType.text);
    });

    test('reads required', () {
      expect(
        FormField.fromJson({'name': 'a', 'required': true}).required,
        true,
      );
      expect(
        FormField.fromJson({'name': 'a', 'required': 'true'}).required,
        true,
      );
      expect(FormField.fromJson({'name': 'a'}).required, false);
    });

    test('a form message keeps its fields and submit label', () {
      final message = ChatMessage.fromJson({
        'messageid': 'm1',
        'channel': 'c1',
        'user': 'agent',
        'message': jsonEncode({
          'messageplain': 'Request a Meeting',
          'ops': [
            {'insert': 'Request a Meeting\n'},
          ],
          'form': [
            {'type': 'hidden', 'name': 'functionname', 'value': 'x_submit'},
            {
              'type': 'datetime-local',
              'name': 'context_meetingtime',
              'label': 'Date and time',
              'required': true,
            },
            {'type': 'textarea', 'name': 'context_meetingmessage'},
          ],
          'submitLabel': 'Request meeting',
        }),
      });

      expect(message.messageRenderType, MessageRenderType.form);
      expect(message.formSubmitLabel, 'Request meeting');
      expect(message.formFields.map((f) => f.type), [
        FormFieldType.hidden,
        FormFieldType.datetime,
        FormFieldType.textarea,
      ]);
      expect(message.formFields[1].required, true);
    });
  });

  group('vendor chat calls', () {
    late List<RequestOptions> seen;
    late int status;
    late Map<String, dynamic> reply;
    late Interceptor interceptor;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      seen = [];
      status = 200;
      reply = {
        'response': {'status': 'ok'},
      };
      interceptor = InterceptorsWrapper(
        onRequest: (o, h) {
          seen.add(o);
          h.resolve(
            Response(requestOptions: o, statusCode: status, data: reply),
          );
        },
      );
      DioUtil.dio.interceptors.add(interceptor);
    });

    tearDown(() => DioUtil.dio.interceptors.remove(interceptor));

    final api = ApiService(config: const ApiConfig(baseUrl: 'http://test'));

    test('connectVendorChat opens the vendor channel', () async {
      reply = {'channel': 'ch9'};
      final channel = await api.connectVendorChat('vendor1');
      expect(channel, 'ch9');
      final o = seen.single;
      expect(
        o.path,
        endsWith('/services/module/librarycollection/connectvendorchat.json'),
      );
      expect(o.queryParameters['collectionid'], 'vendor1');
      expect(o.queryParameters['channeltype'], vendorChatChannelType);
    });

    test('connectVendorChat throws without a channel', () async {
      reply = {
        'response': {'status': 'error'},
      };
      expect(api.connectVendorChat('vendor1'), throwsException);
    });

    test('changeChatScenario runs the step on the channel', () async {
      await api.changeChatScenario(
        'ch9',
        scenarioId: 'eme_chatbot_request_meeting',
        functionName: 'eme_chatbot_request_meeting_confirm',
      );
      final o = seen.single;
      expect(o.path, endsWith('/services/chat/changescenario.json'));
      expect(o.queryParameters, {
        'currentscenario': 'eme_chatbot_request_meeting',
        'functionname': 'eme_chatbot_request_meeting_confirm',
        'channel': 'ch9',
      });
    });

    test('submitChatForm posts the form values', () async {
      await api.submitChatForm('ch9', {
        'functionname': 'eme_chatbot_request_meeting_submit',
        'context_meetingtime': '2026-12-03T14:00',
      });
      final o = seen.single;
      expect(o.path, endsWith('/services/chat/changescenario.json'));
      expect(o.data, {
        'functionname': 'eme_chatbot_request_meeting_submit',
        'context_meetingtime': '2026-12-03T14:00',
        'channel': 'ch9',
      });
    });

    test('a failed submit throws', () async {
      status = 500;
      expect(api.submitChatForm('ch9', {'a': 'b'}), throwsException);
    });
  });
}
