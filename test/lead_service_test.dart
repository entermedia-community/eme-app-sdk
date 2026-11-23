import 'package:dio/dio.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;

  LeadService serviceWith(
    dynamic Function(RequestOptions) respond, {
    int status = 200,
  }) {
    requests = [];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: status,
                data: respond(options),
              ),
            );
          },
        ),
      );
    return LeadService(baseUrl: 'http://test/site/mediadb/', dio: dio);
  }

  const session = LeadSession(
    leadId: 'L1',
    userId: 'visitor-1',
    token: 'tok',
    channel: 'ch1',
  );

  group('fetchVendor', () {
    test('parses the vendor and its menu (real server sample)', () async {
      final service = serviceWith(
        (_) => {
          'response': {'status': 'ok'},
          'vendor': {
            'id': 'AaIJ_oFkvuisFDK6Jo7H',
            'name': 'Vendor 1',
            'urlname': 'VendorOne',
            'menu': [
              {
                'id': 'entity_chat_questions',
                'name': 'Answer Questions',
                'description': 'Good for getting quick answers.',
                'icon': 'broadcast',
                'chatenabled': true,
              },
            ],
          },
        },
      );

      final v = await service.fetchVendor('VendorOne');

      expect(
        requests.single.uri.toString(),
        'http://test/site/mediadb/services/module/librarycollection/vendor.json?urlname=VendorOne',
      );
      expect(v.name, 'Vendor 1');
      expect(v.urlName, 'VendorOne');
      expect(v.menu.single.id, 'entity_chat_questions');
      expect(v.menu.single.icon, 'broadcast');
      expect(v.menu.single.chatEnabled, isTrue);
    });

    test('empty menu is allowed', () async {
      final service = serviceWith(
        (_) => {
          'vendor': {'id': 'V1', 'name': 'V', 'urlname': 'v', 'menu': []},
        },
      );
      expect((await service.fetchVendor('v')).menu, isEmpty);
    });

    test('status error on HTTP 200 throws with the server message', () async {
      final service = serviceWith(
        (_) => {
          'response': {'status': 'error', 'error': 'vendor not found'},
        },
      );
      expect(
        service.fetchVendor('nope'),
        throwsA(
          isA<LeadServiceException>().having(
            (e) => e.message,
            'message',
            contains('vendor not found'),
          ),
        ),
      );
    });
  });

  group('fetchQuestionnaire', () {
    test('parses questions, options and consent', () async {
      final service = serviceWith(
        (_) => {
          'questionnaire': {
            'id': 'Q1',
            'vendorid': 'acme',
            'greeting': 'Hi there!',
            'consenttext': 'May we contact you?',
            'thankyou': 'Thanks!',
            'questions': [
              {
                'id': 'job',
                'prompt': 'Your job?',
                'type': 'text',
                'required': 'true',
              },
              {
                'id': 'budget',
                'prompt': 'Budget?',
                'type': 'radio',
                'options': [
                  {'value': 'lt10', 'label': '< 10k'},
                  {'value': 'gt10', 'label': '10k+'},
                ],
              },
            ],
          },
        },
      );

      final q = await service.fetchQuestionnaire('acme');

      expect(
        requests.single.uri.toString(),
        'http://test/site/mediadb/services/module/lead/questionnaire.json?vendorid=acme',
      );
      expect(q.id, 'Q1');
      expect(q.greeting, 'Hi there!');
      expect(q.consentText, 'May we contact you?');
      expect(q.questions, hasLength(2));
      expect(q.questions.first.required, isTrue);
      expect(q.questions.last.type, FormFieldType.radio);
      expect(q.questions.last.options.map((o) => o.label), ['< 10k', '10k+']);
    });

    test('decodes a JSON string body', () async {
      final service = serviceWith(
        (_) => '{"questionnaire":{"id":"Q1","consenttext":"ok"}}',
      );
      final q = await service.fetchQuestionnaire('acme');
      expect(q.id, 'Q1');
    });

    test('throws on non-2xx', () async {
      final service = serviceWith(
        (_) => {'error': 'unknown vendor'},
        status: 404,
      );
      expect(
        service.fetchQuestionnaire('nope'),
        throwsA(
          isA<LeadServiceException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', contains('unknown vendor')),
        ),
      );
    });

    test('throws when questionnaire is missing', () async {
      final service = serviceWith((_) => {'something': 'else'});
      expect(
        service.fetchQuestionnaire('acme'),
        throwsA(isA<LeadServiceException>()),
      );
    });
  });

  group('startLead', () {
    test('posts name/email and returns a session', () async {
      final service = serviceWith(
        (_) => {
          'lead': {
            'leadid': 'L1',
            'userid': 'visitor-1',
            'token': 'tok',
            'channel': 'ch1',
          },
        },
      );
      final s = await service.startLead(
        vendorId: 'acme',
        questionnaireId: 'Q1',
        name: 'Ada',
        email: 'ada@example.com',
      );
      expect(s.leadId, 'L1');
      expect(s.channel, 'ch1');
      expect(requests.single.data, {
        'vendorid': 'acme',
        'questionnaireid': 'Q1',
        'name': 'Ada',
        'email': 'ada@example.com',
      });
    });

    test('throws when the session is incomplete', () async {
      final service = serviceWith(
        (_) => {
          'lead': {'leadid': 'L1'},
        },
      );
      expect(
        service.startLead(
          vendorId: 'acme',
          questionnaireId: 'Q1',
          name: 'Ada',
          email: 'ada@example.com',
        ),
        throwsA(isA<LeadServiceException>()),
      );
    });
  });

  test('saveAnswer sends the session token', () async {
    final service = serviceWith((_) => {'ok': true});
    await service.saveAnswer(session, questionId: 'job', value: 'CTO');
    final r = requests.single;
    expect(r.path, endsWith('/lead/answer.json'));
    expect(r.headers['entermediakey'], 'tok');
    expect(r.data, {'leadid': 'L1', 'questionid': 'job', 'value': 'CTO'});
  });

  test('saveAnswer throws on server error', () async {
    final service = serviceWith((_) => '', status: 500);
    expect(
      service.saveAnswer(session, questionId: 'job', value: 'CTO'),
      throwsA(isA<LeadServiceException>()),
    );
  });

  test('completeLead returns the thank-you message', () async {
    final service = serviceWith((_) => {'thankyou': 'Thanks Ada!'});
    expect(await service.completeLead(session, consent: true), 'Thanks Ada!');
    expect(requests.single.data, {'leadid': 'L1', 'consent': true});
  });

  test('fetchMessages parses and sorts oldest first', () async {
    final service = serviceWith(
      (_) => {
        'messages': [
          {
            'id': 'm2',
            'channel': 'ch1',
            'user': 'admin',
            'message': 'Second',
            'date': 2000,
          },
          {
            'id': 'm1',
            'channel': 'ch1',
            'user': 'admin',
            'message': 'First',
            'date': 1000,
          },
        ],
      },
    );
    final msgs = await service.fetchMessages(session);
    expect(msgs.map((m) => m.message), ['First', 'Second']);
  });
}
