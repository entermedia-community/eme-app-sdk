import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Server Categories API & Cache Tests', () {
    test('fetchServerCategories parses standard response with id and name', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('categories.json')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'response': {'status': 'ok'},
                    'categories': [
                      {'id': 'rental_gear', 'name': 'Rental & Gear'},
                      {'id': 'mobility', 'name': 'Mobility & Rides'},
                      {'id': 'software', 'name': 'Software Tools'},
                    ],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiService = ApiService(dio: dio);
      final categories = await apiService.fetchServerCategories();
      expect(categories.length, 3);
      expect(categories[0].id, 'rental_gear');
      expect(categories[0].name, 'Rental & Gear');
      expect(categories[1].id, 'mobility');
      expect(categories[1].name, 'Mobility & Rides');
      expect(categories[2].id, 'software');
      expect(categories[2].name, 'Software Tools');
    });

    test('fetchServerCategories handles string list fallback', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('categories.json')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'categories': [
                      'Finance',
                      'Healthcare',
                    ],
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiService = ApiService(dio: dio);
      final categories = await apiService.fetchServerCategories();
      expect(categories.length, 2);
      expect(categories[0].id, 'Finance');
      expect(categories[0].name, 'Finance');
      expect(categories[1].id, 'Healthcare');
      expect(categories[1].name, 'Healthcare');
    });

    test('SharedPref caches ServerCategoryModel list and timestamp', () async {
      final sample = const [
        ServerCategoryModel(id: 'all', name: 'All'),
        ServerCategoryModel(id: 'finance', name: 'Finance'),
        ServerCategoryModel(id: 'healthcare', name: 'Healthcare'),
      ];
      await SharedPref.saveServerCategories(sample);

      final cached = await SharedPref.getCachedServerCategories();
      expect(cached, isNotNull);
      expect(cached!.length, 3);
      expect(cached[0].id, 'all');
      expect(cached[0].name, 'All');
      expect(cached[1].id, 'finance');
      expect(cached[1].name, 'Finance');

      final timestamp = await SharedPref.getServerCategoriesLastFetchTime();
      expect(timestamp, isNotNull);
      expect(DateTime.now().difference(timestamp!).inMinutes < 1, true);
    });

    test('ServerNotifier caches categories and passes category + query to fetchServers', () async {
      int categoriesApiCallCount = 0;
      String? lastPassedCategory;
      String? lastPassedQuery;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('categories.json')) {
              categoriesApiCallCount++;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'categories': [
                      {'id': 'rental_gear', 'name': 'Rental & Gear'},
                      {'id': 'mobility', 'name': 'Mobility & Rides'},
                    ],
                  },
                ),
              );
            } else if (options.path.contains('getemeservers.json')) {
              lastPassedCategory = options.queryParameters['category']?.toString();
              lastPassedQuery = options.queryParameters['query']?.toString();
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'emeservers': []},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final apiService = ApiService(dio: dio);

      // Pre-seed cache
      await SharedPref.saveServerCategories(const [
        ServerCategoryModel(id: 'all', name: 'All'),
        ServerCategoryModel(id: 'old', name: 'Old Cached'),
      ]);

      final notifier = ServerNotifier(apiService: apiService);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.categories.any((c) => c.name == 'All'), true);

      // Non-forced reload within 1 day does not call API
      await notifier.reloadCategories(force: false);
      expect(categoriesApiCallCount, 0);

      // Force refresh updates categories with id and name
      await notifier.refresh();
      expect(categoriesApiCallCount, 1);
      expect(notifier.state.categories.length, 3); // All + 2 categories
      expect(notifier.state.categories[1].id, 'rental_gear');
      expect(notifier.state.categories[1].name, 'Rental & Gear');

      // Test filtering passing category id and search query
      await notifier.loadServersFromApi(category: 'rental_gear', query: 'solar');
      expect(lastPassedCategory, 'rental_gear');
      expect(lastPassedQuery, 'solar');
    });

    test('joinServer throws on error response and toggleJoin captures error', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('join.json')) {
              final serverId = options.queryParameters['serverid'];
              if (serverId == 'fail_srv') {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'response': {
                        'status': 'error',
                        'message': 'Failed to join: quota exceeded',
                      },
                    },
                  ),
                );
              } else {
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'response': {
                        'status': 'ok',
                      },
                    },
                  ),
                );
              }
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'emeservers': []},
              ),
            );
          },
        ),
      );

      final apiService = ApiService(dio: dio);
      final notifier = ServerNotifier(apiService: apiService);
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.addServer(const ServerModel(
        id: 'fail_srv',
        name: 'Fail Server',
        description: 'Fail test description',
        category: 'Test',
        isJoined: false,
      ));
      notifier.addServer(const ServerModel(
        id: 'ok_srv',
        name: 'OK Server',
        description: 'OK test description',
        category: 'Test',
        isJoined: false,
      ));

      // Test failure case
      final failSuccess = await notifier.toggleJoin('fail_srv');
      expect(failSuccess, false);
      expect(notifier.state.error, 'Failed to join: quota exceeded');
      expect(notifier.state.isJoining('fail_srv'), false);
      expect(notifier.state.servers.firstWhere((s) => s.id == 'fail_srv').isJoined, false);

      // Test success case
      final okSuccess = await notifier.toggleJoin('ok_srv');
      expect(okSuccess, true);
      expect(notifier.state.isJoining('ok_srv'), false);
      expect(notifier.state.servers.firstWhere((s) => s.id == 'ok_srv').isJoined, true);
    });
  });
}
