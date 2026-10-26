---
name: eme-sdk-add-api-endpoint
description: Step-by-step recipe for adding or changing a backend call in eme_app_sdk — new IApiService method, new model, Riverpod provider, and test — plus the knock-on update needed in the eme-app-profile test mocks. Use when the user asks to fetch/post new data from an EME server or EnterMedia endpoint, add a service method, wire a new provider, or "hook up" a screen to real data.
---

# Add an API endpoint to the EME SDK

Read the `eme-sdk-overview` skill first if you haven't already.

## 0. Confirm the contract

Before you write code, get the endpoint path, HTTP method, params and a real response sample
from the user (or from a curl against the dev server — default dev mediadb is
`http://localhost:8080/site/mediadb`). **Don't guess at a response shape and never return
mock data if the endpoint isn't ready** (AGENTS.md). If the backend isn't built yet, ask.

## 1. Model (if needed) — `lib/models/<name>_model.dart`

- Immutable class with `final` fields, `const` constructor, `factory fromJson(Map<String, dynamic>)`, `toJson()`.
- Parse defensively the way the existing models do: accept alternate keys (`json['id'] ?? json['_id']`),
  `.toString()` IDs, tolerate numbers sent as strings and bools sent as `"true"`/`"yes"`.
- Export it from `lib/models/models.dart`.

## 2. Contract — `IApiService` in `lib/services/api_service.dart`

Add the method signature to the abstract class. **This is a breaking change for every class that
`implements IApiService`**, which includes:

- `eme-app-profile/test/test_helpers.dart` → `MockApiService`
- any test fakes in `eme-app-sdk/test/`

Update those in the same change, or the app's tests won't compile. Find them with
`grep -rn "implements IApiService" ../eme-app-sdk ../eme-app-profile`.

## 3. Implementation — `ApiService`

Copy the shape of an existing method in the right numbered section (`// 5. CHATS`, etc.):

```dart
@override
Future<List<WidgetThing>> fetchWidgetThings(String serverId) async {
  final cleanBase = _cleanBaseUrl;
  final token = await SharedPref.getEMKey() ?? AuthService.token;
  final url = '$cleanBase/services/module/emeserver/widgetthings.json';

  final response = await _dio.get(
    url,
    queryParameters: {'serverid': serverId},
    options: Options(
      headers: {
        'Content-Type': 'application/json',
        'X-tokentype': 'entermedia',
        if (token != null && token.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'entermediakey': token,
        },
      },
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final status = response.statusCode ?? 0;
  if (status < 200 || status >= 300) {
    throw Exception('fetchWidgetThings failed: HTTP $status');
  }
  dynamic data = response.data;
  if (data is String && data.trim().isNotEmpty) data = jsonDecode(data);
  final list = data is Map<String, dynamic> ? data['widgetthings'] : data;
  if (list is! List) {
    throw const FormatException('fetchWidgetThings: unexpected response shape');
  }
  return list
      .map((e) => WidgetThing.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
```

Notes:

- `DioUtil.dio` accepts every status code, so the explicit status check is required.
- Prefer throwing over the older `catch → return []` style. Record it first with
  `AppErrorHandler.recordNonFatal(e, stack, reason: 'ApiService.x failed', customKeys: {...})` if
  you want Crashlytics visibility, then rethrow.
- For a per-server backend, accept an optional `baseUrl` (see `fetchServerChatMessages`) and pass
  `server.serverMediaDBUrl` from the UI.
- Don't use `print`. The codebase uses `debugPrint('[ApiService] ...')`.

## 4. Provider — `lib/providers/api_providers.dart`

```dart
final serverWidgetThingsProvider =
    FutureProvider.family<List<WidgetThing>, String>((ref, serverId) async {
  final api = ref.watch(apiServiceProvider);
  return api.fetchWidgetThings(serverId);
});
```

Use `StateNotifierProvider` (like `serverProvider`) only when the UI mutates the state (join,
toggle, optimistic updates). Always go through `apiServiceProvider` so tests can override it.

## 5. Tests — `test/`

Mock HTTP with a Dio interceptor, not with branches in `lib/` (see `test/auth_service_test.dart`):

```dart
final dio = Dio()..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
  if (o.path.contains('widgetthings.json')) {
    return h.resolve(Response(requestOptions: o, statusCode: 200,
        data: {'widgetthings': [{'id': '1', 'name': 'A'}]}));
  }
  h.reject(DioException(requestOptions: o));
}));
final api = ApiService(config: const ApiConfig(baseUrl: 'http://test'), dio: dio);
```

Cover: happy path, alternate response keys, non-2xx → throws.

## 6. Verify

```bash
cd ../eme-app-sdk && flutter analyze && flutter test
cd ../eme-app-profile && flutter analyze && flutter test
```

Run the app tests too: they compile against the SDK and hold `MockApiService`.
