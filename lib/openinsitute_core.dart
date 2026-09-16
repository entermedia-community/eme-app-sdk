import 'dart:async' show Future, TimeoutException;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Response;
import 'package:dio/dio.dart';
import 'helper/custom_exception.dart';
import 'helper/request_type.dart';
import 'services/oi_chat_manager.dart';

class AppSettings {
  String mediadb;
  String siteroot;
  String catalogId;
  bool https;

  AppSettings({
    required this.mediadb,
    required this.siteroot,
    required this.catalogId,
    required this.https,
  });

  factory AppSettings.fromJSON(Map<String, dynamic> json) {
    return AppSettings(
      mediadb: json['mediadb'] ?? '',
      siteroot: json['siteroot'] ?? '',
      catalogId: json['catalogid'] ?? '',
      https: json['https'] ?? false,
    );
  }
}

class OpenI {
  late AppSettings _settings;
  OiChatManager? chatManager;

  Future<void> initialize({required Map<String, dynamic> workspaceData}) async {
    _settings = AppSettings.fromJSON(workspaceData);
    Get.put<OpenI>(this, permanent: true);
    chatManager = OiChatManager();
    Get.put<OiChatManager>(chatManager!, permanent: true);
  }

  void updateSettings(Map<String, dynamic> workspaceData) {
    _settings = AppSettings.fromJSON(workspaceData);
  }

  AppSettings get settings {
    return _settings;
  }

  String handleTokenKey(String token) {
    return token;
  }

  //Generic post method to entermedias server
  Future<Map?> postEntermedia(
    String url,
    dynamic jsonBody, {
    String customError = "An Error Occured",
  }) async {
    //Set headers
    Map<String, String> headers = <String, String>{};
    headers.addAll({"X-tokentype": "entermedia"});
    headers.addAll({"Content-type": "application/json"});

    //make API post
    final response = await httpRequest(
      requestUrl: url,
      body: jsonBody,
      headers: headers,
      requestType: RequestType.post,
      customError: customError,
    );
    if (response != null && response.statusCode == 200) {
      final data = response.data;
      debugPrint("Success user info is: $data");
      return data is Map ? data : json.decode(data);
    } else {
      return null;
    }
  }

  //Generic post method to entermedias server
  Future<String> getEmResponse(
    String url,
    dynamic jsonBody,
    RequestType requestType, {
    String customError = "An Error Occured",
  }) async {
    //Set headers
    Map<String, String> headers = <String, String>{};
    headers.addAll({"X-tokentype": "entermedia"});
    headers.addAll({"Content-type": "application/json"});

    final response = await httpRequest(
      requestUrl: url,
      body: jsonBody,
      headers: headers,
      requestType: requestType,
      customError: customError,
    );
    if (response != null && response.statusCode == 200) {
      final String responseString = response.data is String
          ? response.data
          : json.encode(response.data);
      debugPrint("Success user info is: $responseString");
      return responseString;
    } else {
      return "{}";
    }
  }

  Future<Response?> httpRequest({
    required String requestUrl,
    required dynamic body,
    required Map<String, String> headers,
    required RequestType requestType,
    String customError = "Some Error",
  }) async {
    String url = requestUrl;
    debugPrint(url);
    Response response;
    final dio = Dio();
    try {
      Response? responseJson;
      final options = Options(headers: headers);
      if (requestType == RequestType.put) {
        responseJson = await dio.put(url, data: body, options: options);
      } else if (requestType == RequestType.post) {
        responseJson = await dio.post(url, data: body, options: options);
      } else if (requestType == RequestType.get) {
        responseJson = await dio.get(url, options: options);
      } else if (requestType == RequestType.delete) {
        responseJson = await dio.delete(url, data: body, options: options);
      }
      debugPrint('${responseJson?.statusCode}');
      response = await handleException(responseJson!);
      return response;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        // Timeout
      } else if (e.response != null) {
        handleException(e.response!);
      }
    } catch (_) {
      // showErrorFlushbar(
    }
    return null;
  }

  dynamic handleException(Response response) {
    debugPrint("Response code: ${response.statusCode}");
    switch (response.statusCode) {
      case 200:
      case 201:
        return response;
      case 302:
        break;
      case 400:
        throw BadRequestException(response.data.toString());
      case 403:
        throw UnauthorisedException(response.data.toString());
      case 408:
        throw TimeoutException(response.data.toString());
      case 500:
        throw HttpException(response.data.toString());
      default:
        break;
    }
    return response;
  }

  // void registerBinaries() {
  //     final dartToolDir = path.join(Directory.current.path, '.dart_tool');
  //     try {
  //       Isar.initializeLibraries(
  //         libraries: {
  //           'windows': path.join(dartToolDir, 'libisar_windows_x64.dll'),
  //           'macos': path.join(dartToolDir, 'libisar_macos_x64.dylib'),
  //           'linux': path.join(dartToolDir, 'libisar_linux_x64.so'),
  //         },
  //       );
  //     } catch (e) {
  //       // ignore. maybe this is an instrumentation test
  //     }
  //
  // }

  // Future<List<Contact>> testIstarSave() async {
  //   registerBinaries();
  //   final dir = await getApplicationSupportDirectory();
  //
  //   final isar = await Isar.open(
  //     schemas: [ContactSchema],
  //     directory: dir.path,
  //   );
  //
  //   final contact = Contact()
  //     ..name = "My first contact";
  //
  //   await isar.writeTxn((isar) async {
  //     contact.id = await isar.contacts.put(contact) ;
  //   });
  //
  //   final allContacts = await isar.contacts.where().findAll();
  //   debugPrint(allContacts);
  //   return allContacts;
  //
  // }
}
