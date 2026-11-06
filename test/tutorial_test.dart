import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ApiService apiWith(
    Object Function(RequestOptions) respond, {
    int status = 200,
  }) {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: status,
              data: respond(options),
            ),
          ),
        ),
      );
    return ApiService(
      config: const ApiConfig(baseUrl: 'http://test'),
      dio: dio,
    );
  }

  group('tutorial messages', () {
    ChatMessage parse(Map<String, dynamic> context, {String message = ''}) =>
        ChatMessage.fromJson({
          'messageid': 'm1',
          'channel': 'c1',
          'user': 'agent',
          'message': message,
          'date': '2026-11-07T10:00:00Z',
          'agentcontextvalues': context,
        });

    test('question carries its options without empty ones', () {
      final msg = parse({
        'messagerendertype': 'question',
        'interactive': 'yes',
        'tutorialid': 't1',
        'sectionid': 's1',
        'componentid': 'c9',
        'question': {
          'id': 'q1',
          'question': 'Pick one',
          'options': {
            'option_a': 'Red',
            'option_b': 'Blue',
            'option_c': null,
            'option_d': '',
          },
          'correctoption': 'B',
          'rationale': 'Because',
          'mcqcognitivelevel': 'beginner',
        },
      });

      expect(msg.messageRenderType, MessageRenderType.question);
      expect(msg.interactive, isTrue);
      expect(msg.text, 'Pick one');
      expect(msg.contextValues.tutorialId, 't1');
      expect(msg.contextValues.componentId, 'c9');
      final q = msg.question!;
      expect(q.options.keys, ['option_a', 'option_b']);
      expect(q.isCorrectOption('option_b'), isTrue);
      expect(q.isCorrectOption('option_a'), isFalse);
    });

    test('text step shows componentcontent, other steps the message', () {
      final step = parse({
        'messagerendertype': 'text',
        'componentcontent': 'Lesson text',
      }, message: '{"id":"x"}');
      expect(step.text, 'Lesson text');

      final eval = parse({
        'messagerendertype': 'answereval',
        'componentcontent': 'stale',
        'iscorrect': 'true',
        'selectedoption': 'option_b',
        'confidence': 'confident',
      }, message: 'Well done');
      expect(eval.messageRenderType, MessageRenderType.answereval);
      expect(eval.text, 'Well done');
      expect(eval.contextValues.isCorrect, isTrue);
      expect(eval.contextValues.selectedOption, 'option_b');
      expect(eval.contextValues.confidence, TutorialConfidence.confident);
    });

    test('end and progress update have their own types', () {
      expect(
        parse({'messagerendertype': 'end'}).messageRenderType,
        MessageRenderType.end,
      );
      expect(
        parse({'messagerendertype': 'progressupdate'}).messageRenderType,
        MessageRenderType.progressupdate,
      );
    });
  });

  group('tutorial api', () {
    test('topics and tutorials parse and hit the server base url', () async {
      final seen = <RequestOptions>[];
      final api = apiWith((o) {
        seen.add(o);
        if (o.path.contains('topics.json')) {
          return {
            'topics': [
              {'id': 'tp1', 'title': 'Safety', 'tutorials': 2},
            ],
          };
        }
        return {
          'tutorials': [
            {'id': 't1', 'title': 'Fire', 'totalsections': 3},
          ],
        };
      });

      final topics = await api.fetchTutorialTopics(
        baseUrl: 'http://srv/mediadb',
      );
      final tutorials = await api.fetchTutorials(
        'tp1',
        baseUrl: 'http://srv/mediadb',
      );

      expect(
        seen[0].path,
        'http://srv/mediadb/services/module/entitytopic/topics.json',
      );
      expect(seen[1].queryParameters, {'entitytopic': 'tp1'});
      expect(topics.single.title, 'Safety');
      expect(tutorials.single.totalSections, 3);
    });

    test('session returns the channel and sends createnew', () async {
      late RequestOptions seen;
      final api = apiWith((o) {
        seen = o;
        return {
          'channel': {'id': 'ch7', 'channeltype': 'agenttutorchat'},
        };
      });
      final channel = await api.fetchTutorialSession('t1', createNew: true);
      expect(seen.queryParameters, {'dataid': 't1', 'createnew': 'true'});
      expect(channel.id, 'ch7');
    });

    test('a missing channel throws instead of inventing one', () async {
      final api = apiWith(
        (o) => {
          'response': {'status': 'error', 'error': 'nope'},
        },
      );
      expect(() => api.fetchTutorialSession('t1'), throwsA(isA<Exception>()));
      expect(() => api.fetchTutorialTopics(), throwsA(isA<Exception>()));
    });

    test('startTutorial posts the welcome form, non-2xx throws', () async {
      late RequestOptions seen;
      final api = apiWith((o) {
        seen = o;
        return <String, dynamic>{};
      });
      await api.startTutorial('t1', channel: 'ch7');
      expect(seen.method, 'POST');
      expect(seen.data, containsPair('functionname', 'chat_tutor_welcome'));
      expect(seen.data, containsPair('channel', 'ch7'));
      expect(seen.data, containsPair('context_tutorialid', 't1'));

      final failing = apiWith((o) => <String, dynamic>{}, status: 500);
      expect(
        () => failing.startTutorial('t1', channel: 'ch7'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
