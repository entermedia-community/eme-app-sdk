import 'package:flutter/foundation.dart';
import '../models/em_user.dart';
import '../openinsitute_core.dart';
import '../services/shared_preferences.dart';

abstract class IAuthService {
  Future<EmUser?> getCurrentUser();
  Future<String?> getAuthToken();
  Future<EmUser> loginWithCredentials({
    required String username,
    required String password,
  });
  Future<EmUser> loginWithToken(String token);
  Future<void> logout();
  Future<bool> isAuthenticated();
}

class AuthService implements IAuthService {
  final OpenI? openI;
  static String? currentUserId;
  static String? get userId => currentUserId;

  AuthService({this.openI});

  @override
  Future<EmUser?> getCurrentUser() async {
    return SharedPref.getEmUser();
  }

  @override
  Future<String?> getAuthToken() async {
    return SharedPref.getEMKey();
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<EmUser> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    try {
      if (openI != null) {
        final Map<String, dynamic> body = {
          'accountname': username,
          'password': password,
        };
        final response = await openI!.postEntermedia(
          '${openI!.settings.mediadb}/services/authentication/login.json',
          body,
        );

        if (response != null && response['results'] != null) {
          final userJson = response['results'];
          final user = EmUser.fromJson(userJson);
          if (user.entermediakey.isNotEmpty) {
            await SharedPref.saveEMKey(user.entermediakey);
            await SharedPref.saveEmUser(user);
          }
          return user;
        }
      }

      // Fallback/Local login simulation for development
      final mockUser = EmUser.fromJson({
        'id': 'usr_001',
        'email': username.contains('@') ? username : '$username@emeworld.org',
        'screenname': username,
        'entermediakey': 'eme_token_demo_${DateTime.now().millisecondsSinceEpoch}',
      });
      await SharedPref.saveEMKey(mockUser.entermediakey);
      await SharedPref.saveEmUser(mockUser);
      return mockUser;
    } catch (e) {
      debugPrint('AuthService.loginWithCredentials error: $e');
      rethrow;
    }
  }

  @override
  Future<EmUser> loginWithToken(String token) async {
    await SharedPref.saveEMKey(token);
    final existingUser = await getCurrentUser();
    if (existingUser != null) {
      return existingUser;
    }
    final user = EmUser.fromJson({
      'id': 'usr_token_user',
      'email': 'user@emeworld.org',
      'screenname': 'EME Explorer',
      'entermediakey': token,
    });
    await SharedPref.saveEmUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await SharedPref.resetValues();
  }
}
