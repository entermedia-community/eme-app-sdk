import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ApiService apiWith(Map<String, dynamic> Function(RequestOptions) respond) {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
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

  test('fetchEvents parses events and sends filters', () async {
    late RequestOptions seen;
    final api = apiWith((o) {
      seen = o;
      return {
        'response': {'status': 'ok'},
        'events': [
          {
            'id': 'e1',
            'name': 'Beach Cleanup',
            'description': 'Bring gloves',
            'location': 'Pier 3',
            'startdate': '2026-11-02T09:00:00-07:00',
            'goingcount': 4,
            'interestedcount': '2',
            'myrsvp': 'going',
          },
        ],
      };
    });

    final events = await api.fetchEvents(query: 'beach', rsvpedOnly: true);

    expect(seen.path, contains('/services/module/emeevent/events.json'));
    expect(seen.queryParameters, {'query': 'beach', 'rsvped': 'true'});
    expect(events.single.name, 'Beach Cleanup');
    expect(events.single.goingCount, 4);
    expect(events.single.interestedCount, 2);
    expect(events.single.myRsvp, EventRsvp.going);
    expect(events.single.startDate, isNotNull);
    expect(events.single.imageUrl, isNull);
  });

  test('fetchEvents throws on an unexpected response', () async {
    final api = apiWith(
      (_) => {
        'response': {'status': 'error'},
      },
    );
    expect(api.fetchEvents(), throwsException);
  });

  test('fetchEvent throws when the event is missing', () async {
    final api = apiWith((_) => {'events': []});
    expect(api.fetchEvent('nope'), throwsException);
  });

  test('setEventRsvp sends the status and parses the counts', () async {
    late RequestOptions seen;
    final api = apiWith((o) {
      seen = o;
      return {
        'response': {'status': 'ok'},
        'goingcount': 5,
        'interestedcount': 1,
        'myrsvp': 'interested',
      };
    });

    final result = await api.setEventRsvp('e1', EventRsvp.interested);

    expect(seen.path, contains('emeevent/rsvp.json'));
    expect(seen.queryParameters, {'eventid': 'e1', 'status': 'interested'});
    expect(result.goingCount, 5);
    expect(result.myRsvp, EventRsvp.interested);
  });

  test('setEventRsvp throws the server error', () async {
    final api = apiWith(
      (_) => {
        'response': {'status': 'error', 'error': 'Event not found'},
      },
    );
    expect(api.setEventRsvp('x', EventRsvp.going), throwsException);
  });

  test('connectEventChat returns the channel id or throws', () async {
    final ok = apiWith(
      (_) => {
        'response': {'status': 'ok'},
        'channel': 'ch_1',
      },
    );
    expect(await ok.connectEventChat('e1'), 'ch_1');

    final missing = apiWith(
      (_) => {
        'response': {'status': 'not found'},
      },
    );
    expect(missing.connectEventChat('e1'), throwsException);
  });
}
