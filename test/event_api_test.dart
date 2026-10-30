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

  test('createEvent sends ISO dates and returns the created event', () async {
    final seen = <RequestOptions>[];
    final api = apiWith((o) {
      seen.add(o);
      if (o.path.contains('create.json')) {
        return {
          'response': {'status': 'ok'},
          'eventid': 'e9',
        };
      }
      return {
        'events': [
          {'id': 'e9', 'name': 'Potluck', 'myrsvp': 'going'},
        ],
      };
    });

    final event = await api.createEvent(
      name: 'Potluck',
      startDate: DateTime.utc(2026, 11, 2, 18),
      location: 'Park',
    );

    final create = seen.first.queryParameters;
    expect(create['name'], 'Potluck');
    expect(create['eventlocation'], 'Park');
    expect(create.containsKey('enddate'), isFalse);
    expect(
      create['startdate'],
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$')),
    );
    expect(event.id, 'e9');
    expect(event.myRsvp, EventRsvp.going);
  });

  test('createEvent throws the server error', () async {
    final api = apiWith(
      (_) => {
        'response': {'status': 'error', 'error': 'name is required'},
      },
    );
    expect(
      api.createEvent(name: '', startDate: DateTime.now()),
      throwsException,
    );
  });

  test(
    'createProject posts the fields and logo, then loads the project',
    () async {
      final seen = <RequestOptions>[];
      final api = apiWith((o) {
        seen.add(o);
        if (o.path.contains('create.json')) {
          return {
            'response': {'status': 'ok', 'id': 'c9'},
          };
        }
        return {
          'data': {'id': 'c9', 'name': 'Reef', 'urlname': 'reef'},
        };
      });

      final project = await api.createProject(
        name: ' Reef ',
        description: 'Coral work',
        urlName: 'reef',
        tags: ['ocean', 'coral'],
        logo: MultipartFile.fromBytes([1, 2, 3], filename: 'logo.png'),
      );

      final form = seen.first.data as FormData;
      expect(seen.first.path, contains('/librarycollection/create.json'));
      expect(
        form.fields.map((e) => '${e.key}=${e.value}'),
        containsAll([
          'name.value=Reef',
          'collectivedescription.value=Coral work',
          'urlname.value=reef',
          'collectivetags.value=ocean',
          'collectivetags.value=coral',
        ]),
      );
      // The logo must not be a listed field, or the server blanks it.
      expect(form.fields.map((e) => e.value), isNot(contains('assetportrait')));
      expect(form.files.single.key, 'assetportrait');
      expect(project.id, 'c9');
      expect(project.name, 'Reef');
    },
  );

  test('createProject without optional fields sends only the name', () async {
    final seen = <RequestOptions>[];
    final api = apiWith((o) {
      seen.add(o);
      return o.path.contains('create.json')
          ? {
              'response': {'status': 'ok', 'id': 'c1'},
            }
          : {
              'data': {'id': 'c1', 'name': 'Solo'},
            };
    });
    await api.createProject(name: 'Solo');
    final form = seen.first.data as FormData;
    expect(form.fields.map((e) => e.key).toSet(), {'field', 'name.value'});
    expect(form.files, isEmpty);
  });

  test('createProject throws the server error', () async {
    final api = apiWith(
      (_) => {
        'response': {'status': 'error', 'error': 'not allowed'},
      },
    );
    expect(api.createProject(name: 'X'), throwsException);
  });

  test('updateProject sends the fields and reloads the project', () async {
    final seen = <RequestOptions>[];
    final api = apiWith((o) {
      seen.add(o);
      return o.path.contains('update.json')
          ? {
              'response': {'status': 'ok', 'id': 'c9'},
            }
          : {
              'data': {'id': 'c9', 'name': 'Reef 2', 'owner': 'me'},
            };
    });

    final project = await api.updateProject(
      'c9',
      name: ' Reef 2 ',
      description: '',
      urlName: 'reef-2',
      tags: ['ocean'],
    );

    final q = seen.first.queryParameters;
    expect(seen.first.path, contains('/librarycollection/update.json'));
    expect(q['collectionid'], 'c9');
    expect(q['field'], [
      'name',
      'collectivedescription',
      'urlname',
      'collectivetags',
    ]);
    expect(q['name.value'], ['Reef 2']);
    expect(q['collectivedescription.value'], ['']);
    expect(q['collectivetags.value'], ['ocean']);
    expect(project.isOwnedBy('me'), isTrue);
    expect(project.isOwnedBy('you'), isFalse);
  });

  test('updateProject throws the server error', () async {
    final api = apiWith(
      (_) => {
        'response': {'status': 'error', 'error': 'Only the project owner'},
      },
    );
    expect(api.updateProject('c9', name: 'X'), throwsException);
  });

  test('ServerModel reads isowner', () {
    final owner = ServerModel.fromJson({
      'id': 's1',
      'name': 'Lakeview',
      'isowner': true,
    });
    final member = ServerModel.fromJson({'id': 's2', 'name': 'Other'});
    expect(owner.isOwner, isTrue);
    expect(member.isOwner, isFalse);
  });
}
