import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'error_handler.dart';

class DioUtil {
  static CookieJar? _cookieJar;
  static Dio? _dio;

  static Dio get dio {
    _dio ??= Dio(BaseOptions(validateStatus: (status) => true));
    return _dio!;
  }

  static Future<void> clearCookies() async {
    try {
      if (_cookieJar != null) {
        await _cookieJar!.deleteAll();
      }
    } catch (e, stack) {
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'DioUtil.clearCookies failed',
      );
    }
  }

  static Future<void> init() async {
    final dioInstance = Dio(BaseOptions(validateStatus: (status) => true));
    _dio = dioInstance;

    if (kIsWeb) {
      _cookieJar = CookieJar();
    } else {
      try {
        final dir = await getApplicationSupportDirectory();
        final jar = PersistCookieJar(
          storage: FileStorage('${dir.path}/.cookies/'),
        );
        _cookieJar = jar;
        dioInstance.interceptors.add(CookieManager(jar));
      } catch (e, stack) {
        AppErrorHandler.recordNonFatal(
          e,
          stack,
          reason:
              'DioUtil.init persistent cookie storage failed, fallback to memory',
        );
        final jar = CookieJar();
        _cookieJar = jar;
        dioInstance.interceptors.add(CookieManager(jar));
      }
    }
  }
}
