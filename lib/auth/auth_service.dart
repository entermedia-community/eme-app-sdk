import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
export 'package:dio/dio.dart' show MultipartFile, FormData;
import '../models/em_user.dart';
import '../openinsitute_core.dart';
import '../services/shared_preferences.dart';
import '../utils/dio.dart';
import '../utils/error_handler.dart';
import 'auth_state.dart';

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

  static String? currentUserId;
  static String? get userId => currentUserId;
  static String? currentToken;
  static String? get token => currentToken;

  AuthService({OpenI? openI, Dio? dio, String? baseUrl})
    : openI = openI ?? OpenI.instance,
      _dio = dio ?? DioUtil.dio,
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
          headers: {
            'Content-Type': 'application/json',
            'X-tokentype': 'entermedia',
          },
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
      throw Exception('AuthService.sendUserCode failed');
    } catch (e, stack) {
      debugPrint('[AuthService] sendUserCode error: $e');
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'AuthService.sendUserCode failed',
        customKeys: {'email': cleanEmail},
      );
      throw Exception('AuthService.sendUserCode failed');
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

    final body = <String, dynamic>{
      'grant_type': 'otp',
      'email': cleanEmail,
      'code': cleanCode,
    };

    debugPrint('[AuthService] loginWithCode POST URL: $url');
    debugPrint('[AuthService] loginWithCode Payload: ${jsonEncode(body)}');

    try {
      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-tokentype': 'entermedia',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[AuthService] loginWithCode Response [${response.statusCode}]: ${response.data}',
      );

      final dynamic data = response.data;
      Map<String, dynamic> jsonMap = {};
      if (data is Map<String, dynamic>) {
        jsonMap = data;
      } else if (data is String && data.trim().isNotEmpty) {
        jsonMap = jsonDecode(data);
      }

      final result = LoginResult.fromJson(jsonMap);

      if (result.isSuccess && result.token != null) {
        await SharedPref.saveEMKey(result.token!);
        currentToken = result.token;
        if (result.user != null) {
          await SharedPref.saveEmUser(result.user!);
          currentUserId = result.user!.username;
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
      throw Exception('AuthService.loginWithCode failed');
    }
  }

  @override
  Future<EmUser?> checkAuthSession() async {
    final token = await getAuthToken();
    if (token == null || token.trim().isEmpty) {
      currentUserId = null;
      return null;
    }

    final cachedUser = await getCurrentUser();
    if (cachedUser != null) {
      currentUserId = cachedUser.username;
    }

    final url = _cleanUrl('/services/authentication/user.json');

    debugPrint('[AuthService] checkAuthSession POST URL: $url');
    debugPrint(
      '[AuthService] checkAuthSession Headers: Authorization Bearer $token, entermediakey: $token',
    );

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-tokentype': 'entermedia',
            'Authorization': 'Bearer $token',
            'entermediakey': token,
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
        // Token expired/invalid
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

    final token = await getAuthToken();
    final url = _cleanUrl('/services/module/user/usersearch.json');

    debugPrint('[AuthService] searchUsers GET URL: $url?term=$cleanQuery');

    try {
      final response = await _dio.get(
        url,
        queryParameters: {'term': cleanQuery},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-tokentype': 'entermedia',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
            if (token != null && token.isNotEmpty) 'entermediakey': token,
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
    final token = await getAuthToken();
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
          headers: {
            'X-tokentype': 'entermedia',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
            if (token != null && token.isNotEmpty) 'entermediakey': token,
          },
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
    await SharedPref.resetValues();
    await DioUtil.clearCookies();
    currentUserId = null;
    currentToken = null;
  }
}
