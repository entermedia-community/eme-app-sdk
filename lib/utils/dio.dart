import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'error_handler.dart';

class DioUtil {
  static late CookieJar _cookieJar;
  static late Dio _dio;
  static Dio get dio => _dio;

  static Future<void> clearCookies() async {
    try {
      await _cookieJar.deleteAll();
    } catch (e, stack) {
      AppErrorHandler.recordNonFatal(
        e,
        stack,
        reason: 'DioUtil.clearCookies failed',
      );
    }
  }

  static Future<void> init() async {
    _dio = Dio(BaseOptions(validateStatus: (status) => true));

    // _dio.interceptors.add(
    //   InterceptorsWrapper(
    //     onRequest: (options, handler) {
    //       final langCode = Workspace.currentLanguage.languageCode.toLowerCase();
    //       options.headers['Accept-Language'] =
    //           langCode == 'es' ? 'es-ES' : 'en-US';
    //       handler.next(options);
    //     },
    //   ),
    // );

    if (kIsWeb) {
      _cookieJar = CookieJar();
      // Browsers handle cookies automatically;
      // we initialize an in-memory CookieJar to avoid null errors.
    } else {
      try {
        final dir = await getApplicationSupportDirectory();
        _cookieJar = PersistCookieJar(
          storage: FileStorage('${dir.path}/.cookies/'),
        );
        _dio.interceptors.add(CookieManager(_cookieJar));
      } catch (e, stack) {
        AppErrorHandler.recordNonFatal(
          e,
          stack,
          reason:
              'DioUtil.init persistent cookie storage failed, fallback to memory',
        );
        _cookieJar = CookieJar();
      }
    }
  }
}
