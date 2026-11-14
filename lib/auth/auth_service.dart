import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
export 'package:dio/dio.dart' show MultipartFile, FormData;
import '../models/em_user.dart';
import '../openinsitute_core.dart';
import '../services/shared_preferences.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';
import 'auth_state.dart';
import 'device_key_platform.dart';
import 'device_key_store.dart';
import 'firebase_credential_store.dart';
import 'signed_token.dart';

abstract class IAuthService {
  Future<SendUserCodeResult> sendUserCode({
    required String email,
    String? firstName,
    String? lastName,
  });

  Future<LoginResult> loginWithCode({
    required String email,
    required String code,
  });

  Future<List<EmUser>> searchUsers(String query);
  Future<EmUser?> checkAuthSession();
  Future<EmUser?> getCurrentUser();
  Future<String?> getAuthToken();

  /// The Firebase Auth login saved by the last code login, used to receive
  /// push notifications. Null when the server did not provide one.
  Future<FirebaseCredentials?> getFirebaseCredentials();

  /// Signs in again with this device's registered key (`grant_type=key`).
  /// Returns false when there is no key or the server rejects it.
  Future<bool> refreshToken();

  /// Starts a session on another EME Server (e.g. impactbank.world, given by
  /// its mediadb URL) for the user signed in on this root server. Posts a
  /// freshly signed key login to that server's `tokenremote.json`, which
  /// forwards it here to verify; the session cookie it returns is kept for
  /// the app's later requests to that server. Does nothing when the URL is
  /// this root server. Throws when there is no device key or the login is
  /// refused.
  Future<void> authenticateRemoteServer(String serverMediaDbUrl);
  Future<void> logout();
  Future<bool> isAuthenticated();
  Future<void> saveUserFields(
    List<MapEntry<String, String>> fields, {
    MultipartFile? portrait,
  });
}

class AuthService implements IAuthService {
  final OpenI? openI;
  final Dio _dio;
  final String baseUrl;
  final DeviceKeyStore _keyStore;
  final FirebaseCredentialStore _firebaseStore;
  final SignedTokenProvider _signedToken;

  static String? currentUserId;
  static String? get userId => currentUserId;
  static String? currentToken;
  static String? get token => currentToken;
  static String? currentFirebasePassword;
  static String? get firebasePassword => currentFirebasePassword;
  static String? currentUserEmail;
  static String? get email => currentUserEmail;

  AuthService({
    OpenI? openI,
    Dio? dio,
    String? baseUrl,
    DeviceKeyStore? keyStore,
    FirebaseCredentialStore? firebaseStore,
    SignedTokenProvider? signedToken,
  }) : openI = openI ?? OpenI.instance,
       _dio = dio ?? DioUtil.dio,
       _keyStore = keyStore ?? createPlatformKeyStore(),
       _firebaseStore = firebaseStore ?? const SecureFirebaseCredentialStore(),
       _signedToken =
           signedToken ??
           (keyStore == null
               ? SignedTokenProvider.instance
               : SignedTokenProvider(keyStore: keyStore)),
       baseUrl = baseUrl ?? (openI ?? OpenI.instance)?.settings.mediadb ?? '';

  String _cleanUrl(String path) {
    final effectiveOpenI = openI ?? OpenI.instance;
    var base =
        (effectiveOpenI != null && effectiveOpenI.settings.mediadb.isNotEmpty)
        ? effectiveOpenI.settings.mediadb.trim()
        : baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var cleanPath = path;
    if (base.endsWith('/mediadb') && cleanPath.startsWith('/mediadb')) {
      cleanPath = cleanPath.substring('/mediadb'.length);
    }
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    return '$base$cleanPath';
  }

  @override
  Future<SendUserCodeResult> sendUserCode({
    required String email,
    String? firstName,
    String? lastName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final url = _cleanUrl('/services/authentication/sendusercode.json');

    final body = <String, dynamic>{
      'email': cleanEmail,
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstname': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastname': lastName.trim(),
    };

    debugPrint('[AuthService] sendUserCode POST URL: $url');
    debugPrint('[AuthService] sendUserCode Payload: ${jsonEncode(body)}');

    try {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[AuthService] sendUserCode Response [${response.statusCode}]: ${response.data}',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonMap = {};
      if (data is Map<String, dynamic>) {
        jsonMap = data;
      } else if (data is String && data.trim().isNotEmpty) {
        jsonMap = jsonDecode(data);
      }

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300 && jsonMap.isNotEmpty) {
        return SendUserCodeResult.fromJson(jsonMap);
      }
      throw Exception('Invalid response from sendUserCode');
    } catch (e, stack) {
      debugPrint('[AuthService] sendUserCode error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.sendUserCode failed',
        customKeys: {'email': cleanEmail},
      );
      return SendUserCodeResult(
        status: SendUserCodeStatus.nouser,
        email: email,
        allowGuestRegistration: true,
      );
    }
  }

  @override
  Future<LoginResult> loginWithCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();
    final url = _cleanUrl('/services/authentication/token.json');

    // The code login also registers this device's public key, so later
    // sessions renew themselves by signing instead of asking for a new code.
    final signer = await createPlatformSigner();
    final body = <String, dynamic>{
      'grant_type': 'otp',
      'email': cleanEmail,
      'code': cleanCode,
      if (signer != null) 'publickey': await signer.publicKey(),
      'label': _deviceLabel,
      'firebaseenabled': true,
    };

    debugPrint('[AuthService] loginWithCode POST URL: $url');

    try {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[AuthService] loginWithCode Response [${response.statusCode}]',
      );

      final result = LoginResult.fromJson(_decodeMap(response.data));

      if (result.isSuccess && result.token != null) {
        if (signer != null) {
          final keyId = result.keyId;
          if (keyId == null || keyId.isEmpty || result.user == null) {
            return LoginResult(
              isSuccess: false,
              errorMessage: 'The server did not register this device key',
            );
          }
          await _keyStore.save(
            DeviceKey(
              keyId: keyId,
              username: result.user!.username,
              signer: signer,
            ),
          );
        } else {
          debugPrint('[AuthService] No device key support; code login only');
        }
        // getAuthToken/checkAuthSession and ApiService read it back from here.
        await SharedPref.saveEMKey(result.token!);
        currentToken = result.token;
        await SharedPref.saveEmUser(result.user!);
        currentUserId = result.user!.username;
        currentUserEmail = cleanEmail;

        final firebasePassword = result.firebasePassword;
        if (firebasePassword != null && firebasePassword.isNotEmpty) {
          currentFirebasePassword = firebasePassword;
          await _firebaseStore.save(
            FirebaseCredentials(email: cleanEmail, password: firebasePassword),
          );
        } else {
          // Login still works, but push notifications cannot be set up.
          debugPrint('[AuthService] Server returned no firebasepassword');
          await _firebaseStore.clear();
        }
      }

      return result;
    } catch (e, stack) {
      debugPrint('[AuthService] loginWithCode error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.loginWithCode failed, trying fallback',
        customKeys: {'email': cleanEmail},
      );
      return LoginResult(
        isSuccess: false,
        errorMessage: 'Invalid or expired verification code',
      );
    }
  }

  static const _deviceLabel = 'EME app';

  Map<String, dynamic> _decodeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return {};
  }

  /// A `grant_type=key` login signed with this device's key, or null when the
  /// device has no key. Every call uses a new nonce, so each server gets its
  /// own payload (the root rejects a nonce it has already seen).
  Future<Map<String, String>?> _signedKeyLogin() async {
    final key = await _keyStore.read();
    if (key == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = DeviceKeyCrypto.b64url(
      List<int>.generate(24, (_) => Random.secure().nextInt(256)),
    );
    final signature = await key.signer.sign(
      DeviceKeyCrypto.loginMessage(
        username: key.username,
        keyId: key.keyId,
        timestamp: timestamp,
        nonce: nonce,
      ),
    );
    return {
      'grant_type': 'key',
      'username': key.username,
      'key_id': key.keyId,
      'timestamp': timestamp,
      'nonce': nonce,
      'signature': signature,
    };
  }

  @override
  Future<void> authenticateRemoteServer(String serverMediaDbUrl) async {
    var remoteBase = serverMediaDbUrl.trim();
    while (remoteBase.endsWith('/')) {
      remoteBase = remoteBase.substring(0, remoteBase.length - 1);
    }
    if (remoteBase.isEmpty) {
      throw ArgumentError.value(serverMediaDbUrl, 'serverMediaDbUrl');
    }
    final remoteUri = Uri.tryParse(remoteBase);
    final rootUri = Uri.tryParse(_cleanUrl(''));
    if (remoteUri != null &&
        rootUri != null &&
        remoteUri.host == rootUri.host &&
        remoteUri.port == rootUri.port) {
      return; // The root server itself: already signed in here
    }

    final payload = await _signedKeyLogin();
    if (payload == null) {
      throw Exception('This device has no sign-in key; sign in again');
    }

    final url = '$remoteBase/services/authentication/tokenremote.json';
    final Response response;
    try {
      response = await _dio.post(
        url,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
    } catch (e, stack) {
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.authenticateRemoteServer failed',
        customKeys: {'url': url},
      );
      throw Exception('Could not reach $remoteBase');
    }

    final data = _decodeMap(response.data);
    final status = response.statusCode ?? 0;
    if (status != 200 || data['session'] != true) {
      final error = data['error']?.toString();
      debugPrint(
        '[AuthService] authenticateRemoteServer $url refused [$status]: $error',
      );
      throw Exception(
        error != null && error.isNotEmpty
            ? 'Sign-in to this server failed: $error'
            : 'Sign-in to this server failed (HTTP $status)',
      );
    }
  }

  @override
  Future<bool> refreshToken() async {
    final payload = await _signedKeyLogin();
    if (payload == null) return false;

    try {
      final response = await _dio.post(
        _cleanUrl('/services/authentication/token.json'),
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final result = LoginResult.fromJson(_decodeMap(response.data));
      if (!result.isSuccess || result.token == null) {
        debugPrint(
          '[AuthService] refreshToken rejected: ${result.errorMessage}',
        );
        return false;
      }
      await SharedPref.saveEMKey(result.token!);
      currentToken = result.token;
      if (result.user != null) {
        await SharedPref.saveEmUser(result.user!);
        currentUserId = result.user!.username;
      }
      return true;
    } catch (e, stack) {
      debugPrint('[AuthService] refreshToken error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.refreshToken failed',
      );
      return false;
    }
  }

  @override
  Future<EmUser?> checkAuthSession() => _checkAuthSession(retry: true);

  Future<EmUser?> _checkAuthSession({required bool retry}) async {
    final token = await getAuthToken();
    if (token == null || token.trim().isEmpty) {
      currentUserId = null;
      currentToken = null;
      return null;
    }
    // A restored session only has the saved key; ChatSocketService (chat
    // connect.json, the socket) reads it from here.
    currentToken = token;

    final cachedUser = await getCurrentUser();
    if (cachedUser != null) {
      currentUserId = cachedUser.username;
    }

    final url = _cleanUrl('/services/authentication/user.json');

    debugPrint('[AuthService] checkAuthSession POST URL: $url');
    debugPrint('[AuthService] checkAuthSession signed with X-token');

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...await _signedToken.headers(),
          },
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      debugPrint(
        '[AuthService] checkAuthSession Response [${response.statusCode}]: ${response.data}',
      );

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        Map<String, dynamic> jsonMap = {};
        if (data is Map<String, dynamic>) {
          jsonMap = data;
        } else if (data is String && data.trim().isNotEmpty) {
          jsonMap = jsonDecode(data);
        }

        final userJson = jsonMap['user'] is Map<String, dynamic>
            ? jsonMap['user'] as Map<String, dynamic>
            : (jsonMap['response'] is Map<String, dynamic>
                  ? jsonMap['response'] as Map<String, dynamic>
                  : jsonMap);

        if (userJson.isNotEmpty && userJson['id'] != null) {
          final user = EmUser.fromJson(userJson);
          await SharedPref.saveEmUser(user);
          currentUserId = user.username;
          return user;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // The server refused the signed X-token (key revoked or token
        // rejected). Drop the stored token and try once with a fresh nonce and
        // signature; only a rejected key means the user must use a new code.
        await _signedToken.clear();
        if (retry && await refreshToken()) {
          return await _checkAuthSession(retry: false);
        }
        await logout();
        return null;
      }

      // Return cached user if endpoint unavailable (e.g. offline)
      return cachedUser;
    } catch (e, stack) {
      debugPrint('[AuthService] checkAuthSession error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason:
            'AuthService.checkAuthSession failed, using cached session if any',
      );
      return cachedUser;
    }
  }

  @override
  Future<EmUser?> getCurrentUser() async {
    final user = await SharedPref.getEmUser();
    if (user != null) {
      currentUserId = user.username;
    }
    return user;
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
  Future<List<EmUser>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final url = _cleanUrl('/services/module/user/usersearch.json');

    debugPrint('[AuthService] searchUsers GET URL: $url?term=$cleanQuery');

    try {
      final response = await _dio.get(
        url,
        queryParameters: {'term': cleanQuery},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...await _signedToken.headers(),
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[AuthService] searchUsers Response [${response.statusCode}]: ${response.data}',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonMap = {};
      if (data is Map<String, dynamic>) {
        jsonMap = data;
      } else if (data is String && data.trim().isNotEmpty) {
        jsonMap = jsonDecode(data);
      }

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300 && jsonMap.isNotEmpty) {
        final usersList = (jsonMap['users'] as List<dynamic>?) ?? [];
        return usersList
            .map((item) => EmUser.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e, stack) {
      debugPrint('[AuthService] searchUsers error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.searchUsers failed',
        customKeys: {'query': cleanQuery},
      );
      return [];
    }
  }

  @override
  Future<void> saveUserFields(
    List<MapEntry<String, String>> fields, {
    MultipartFile? portrait,
  }) async {
    final url = _cleanUrl('/services/authentication/usersave.json');
    final uid = currentUserId ?? (await getCurrentUser())?.username ?? '';

    final formData = FormData();
    formData.fields.add(const MapEntry('save', 'true'));
    formData.fields.add(MapEntry('userid', uid));
    formData.fields.add(MapEntry('username', uid));
    for (final entry in fields) {
      formData.fields.add(entry);
    }
    if (portrait != null) {
      formData.fields.add(const MapEntry('field', 'assetportrait'));
      formData.files.add(MapEntry('file.assetportrait', portrait));
    }

    debugPrint('[AuthService] saveUserFields POST URL: $url');

    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {...await _signedToken.headers()},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      debugPrint(
        '[AuthService] saveUserFields Response [${response.statusCode}]: ${response.data}',
      );
    } catch (e, stack) {
      debugPrint('[AuthService] saveUserFields error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.saveUserFields failed',
        customKeys: {'userid': uid},
      );
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _revokeDeviceKey();
    await _firebaseStore.clear();
    await _signedToken.clear();
    await SharedPref.resetValues();
    await DioUtil.clearCookies();
    currentUserId = null;
    currentToken = null;
    currentUserEmail = null;
    currentFirebasePassword = null;
  }

  @override
  Future<FirebaseCredentials?> getFirebaseCredentials() =>
      _firebaseStore.read();

  /// Revokes this device's key on the server (best effort, the token may
  /// already be dead) and deletes the private key from the device.
  Future<void> _revokeDeviceKey() async {
    final key = await _keyStore.read();
    if (key == null) return;
    final token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _dio.post(
          _cleanUrl('/services/authentication/revokekey.json'),
          data: {'keyid': key.keyId},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {...await _signedToken.headers()},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('[AuthService] revokekey failed: $e');
      }
    }
    await _keyStore.clear();
  }
}
