import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eme_app_sdk/eme_app_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService Tests', () {
    test('sendUserCode handles success, nouser, and error', () async {
      final authService = AuthService();

      // 1. Success case
      final okRes = await authService.sendUserCode(email: 'test@emeworld.org');
      expect(okRes.isSuccess, true);
      expect(okRes.status, SendUserCodeStatus.ok);

      // 2. No user case
      final noUserRes = await authService.sendUserCode(email: 'newuser@emeworld.org');
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
      final authService = AuthService();

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
      final authService = AuthService();

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
        'response': {
          'status': 'ok',
          'email': 'user@example.com',
        }
      };
      final okResult = SendUserCodeResult.fromJson(okJson);
      expect(okResult.isSuccess, true);
      expect(okResult.email, 'user@example.com');

      final noUserJson = {
        'response': {
          'status': 'nouser',
          'email': 'user@example.com',
          'allowguestregistration': true,
        }
      };
      final noUserResult = SendUserCodeResult.fromJson(noUserJson);
      expect(noUserResult.isNoUser, true);
      expect(noUserResult.allowGuestRegistration, true);

      final loginJson = {
        'response': {
          'status': 'ok',
          'user': 'usr_99',
        },
        'entermediakey': 'token_xyz123',
        'user': {
          'id': 'usr_99',
          'firstname': 'Jane',
          'lastname': 'Smith',
          'email': 'jane@example.com',
          'screenname': 'janesmith',
        }
      };
      final loginResult = LoginResult.fromJson(loginJson);
      expect(loginResult.isSuccess, true);
      expect(loginResult.token, 'token_xyz123');
      expect(loginResult.user?.fullName, 'Jane Smith');
      expect(loginResult.user?.displayName, 'janesmith');
    });
  });
}
