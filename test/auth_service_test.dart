import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

Dio createMockAuthDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final data = options.data is Map ? options.data as Map : {};
        if (path.contains('sendusercode.json')) {
          final email = data['email']?.toString() ?? '';
          if (email.contains('new') && data['firstname'] == null) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'response': {
                    'status': 'nouser',
                    'email': email,
                    'allowguestregistration': true,
                  },
                },
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'response': {'status': 'ok', 'email': email},
              },
            ),
          );
        } else if (path.contains('token.json')) {
          final code = data['code']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';
          if (code.length < 6 || code == '123') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 400,
                data: {
                  'error': 'invalid_grant',
                  'error_description': 'Invalid code',
                },
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'response': {'status': 'ok'},
                'entermediakey':
                    'mock_token_${DateTime.now().millisecondsSinceEpoch}',
                'user': {
                  'username': 'usr_${email.split('@').first}',
                  'email': email,
                  'firstname': email.split('@').first,
                  'lastname': 'User',
                  'screenname': email.split('@').first,
                },
              },
            ),
          );
        } else if (path.contains('firebaselogin.json')) {
          final email = data['email']?.toString() ?? '';
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'results': {
                  'username': 'usr_${email.split('@').first}',
                  'email': email,
                  'firstname': 'Firebase',
                  'lastname': 'User',
                  'firebasepassword': data['password'],
                },
              },
            ),
          );
        } else if (path.contains('authentication/user.json')) {
          final authHeader = options.headers['Authorization']?.toString() ?? '';
          if (authHeader.isEmpty || authHeader.contains('null')) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 401,
                data: {'error': 'unauthorized'},
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'response': {'status': 'ok'},
                'user': {
                  'username': 'usr_bob',
                  'email': 'bob@emeworld.org',
                  'firstname': 'bob',
                  'lastname': 'User',
                  'screenname': 'bob',
                },
              },
            ),
          );
        } else if (path.contains('usersearch.json') ||
            path.contains('users.json')) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'users': [
                  {
                    'username': 'admin',
                    'firstname': 'The',
                    'lastname': 'Administrator',
                    'email': 'support@entermediadb.org',
                    'assetportrait':
                        'http://localhost:8080/site/mediadb/services/module/asset/generated/Users/The.A/jefferson-santos-9SoCnyQmkzI-unsplash.jpg/image200x200.webp',
                  },
                ],
              },
            ),
          );
        }
        return handler.next(options);
      },
    ),
  );
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService Tests', () {
    test('sendUserCode handles success, nouser, and error', () async {
      final authService = AuthService(dio: createMockAuthDio());

      // 1. Success case
      final okRes = await authService.sendUserCode(email: 'test@emeworld.org');
      expect(okRes.isSuccess, true);
      expect(okRes.status, SendUserCodeStatus.ok);

      // 2. No user case
      final noUserRes = await authService.sendUserCode(
        email: 'newuser@emeworld.org',
      );
      expect(noUserRes.isNoUser, true);
      expect(noUserRes.allowGuestRegistration, true);

      // 3. Guest registration case
      final guestRes = await authService.sendUserCode(
        email: 'newuser@emeworld.org',
        firstName: 'John',
        lastName: 'Doe',
      );
      expect(guestRes.isSuccess, true);
    });

    test('loginWithCode authenticates and saves session', () async {
      final authService = AuthService(dio: createMockAuthDio());

      // 1. Invalid code
      final invalidRes = await authService.loginWithCode(
        email: 'alice@emeworld.org',
        code: '123',
      );
      expect(invalidRes.isSuccess, false);
      expect(invalidRes.errorMessage, isNotNull);

      // 2. Valid 6-digit OTP code
      final validRes = await authService.loginWithCode(
        email: 'alice@emeworld.org',
        code: '849201',
      );
      expect(validRes.isSuccess, true);
      expect(validRes.user, isNotNull);
      expect(validRes.token, isNotNull);
      expect(validRes.user?.email, 'alice@emeworld.org');

      // 3. Verify session was stored
      final token = await authService.getAuthToken();
      expect(token, isNotNull);
      final currentUser = await authService.getCurrentUser();
      expect(currentUser?.email, 'alice@emeworld.org');
      expect(await authService.isAuthenticated(), true);

      // 4. Logout
      await authService.logout();
      expect(await authService.isAuthenticated(), false);
      expect(await authService.getCurrentUser(), isNull);
    });

    test('checkAuthSession verifies cached session', () async {
      final authService = AuthService(dio: createMockAuthDio());

      // Initially no session
      final initialSession = await authService.checkAuthSession();
      expect(initialSession, isNull);

      // Login
      await authService.loginWithCode(
        email: 'bob@emeworld.org',
        code: '654321',
      );

      // Verify checkAuthSession recovers user
      final activeUser = await authService.checkAuthSession();
      expect(activeUser, isNotNull);
      expect(activeUser?.email, 'bob@emeworld.org');
    });

    test('SendUserCodeResult and LoginResult JSON parsing', () {
      final okJson = {
        'response': {'status': 'ok', 'email': 'user@example.com'},
      };
      final okResult = SendUserCodeResult.fromJson(okJson);
      expect(okResult.isSuccess, true);
      expect(okResult.email, 'user@example.com');

      final noUserJson = {
        'response': {
          'status': 'nouser',
          'email': 'user@example.com',
          'allowguestregistration': true,
        },
      };
      final noUserResult = SendUserCodeResult.fromJson(noUserJson);
      expect(noUserResult.isNoUser, true);
      expect(noUserResult.allowGuestRegistration, true);

      final loginJson = {
        'response': {'status': 'ok', 'user': 'usr_99'},
        'entermediakey': 'token_xyz123',
        'user': {
          'username': 'usr_99',
          'firstname': 'Jane',
          'lastname': 'Smith',
          'email': 'jane@example.com',
          'screenname': 'janesmith',
        },
      };
      final loginResult = LoginResult.fromJson(loginJson);
      expect(loginResult.isSuccess, true);
      expect(loginResult.token, 'token_xyz123');
      expect(loginResult.user?.fullName, 'Jane Smith');
      expect(loginResult.user?.displayName, 'janesmith');

      final oauthTokenJson = {
        'access_token': 'oauth_token_789',
        'token_type': 'bearer',
        'email': 'tokenuser@example.com',
      };
      final oauthResult = LoginResult.fromJson(oauthTokenJson);
      expect(oauthResult.isSuccess, true);
      expect(oauthResult.token, 'oauth_token_789');
      expect(oauthResult.user?.email, 'tokenuser@example.com');
    });

    test(
      'searchUsers queries users endpoint and parses user results',
      () async {
        final authService = AuthService(dio: createMockAuthDio());
        final results = await authService.searchUsers('admin');
        expect(results.isNotEmpty, true);
        expect(results.first.username, 'admin');
        expect(results.first.firstname, 'The');
        expect(results.first.lastname, 'Administrator');
        expect(results.first.email, 'support@entermediadb.org');
        expect(results.first.assetportrait, contains('jefferson-santos'));
      },
    );
  });
}
