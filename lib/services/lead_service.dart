import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../models/lead_model.dart';
import '../openinsitute_core.dart';
import '../utils/dio.dart';

/// Thrown when a lead endpoint fails or answers in an unexpected shape.
class LeadServiceException implements Exception {
  final String message;
  final int? statusCode;
  const LeadServiceException(this.message, {this.statusCode});
  @override
  String toString() => 'LeadServiceException: $message';
}

/// Public (no login) lead-capture endpoints used by the embeddable chatbot.
/// The contract is documented in `docs/lead_api.md`.
abstract class ILeadService {
  /// Vendor (`librarycollection`, `collectiontype=8`) whose `urlname` matches
  /// exactly, with its menu. Throws when there is no such vendor.
  Future<VendorModel> fetchVendor(String urlName);

  Future<LeadQuestionnaire> fetchQuestionnaire(String vendorId);

  Future<LeadSession> startLead({
    required String vendorId,
    required String questionnaireId,
    required String name,
    required String email,
  });

  Future<void> saveAnswer(
    LeadSession session, {
    required String questionId,
    required dynamic value,
  });

  /// Records consent and marks the lead complete. Returns the server's
  /// thank-you message, if it sends one.
  Future<String?> completeLead(LeadSession session, {required bool consent});

  /// Messages on the lead's channel (admin replies, email logs), oldest first.
  Future<List<ChatMessage>> fetchMessages(LeadSession session);
}

class LeadService implements ILeadService {
  LeadService({this.baseUrl, Dio? dio}) : _dio = dio ?? DioUtil.dio;

  /// mediadb base URL; defaults to `OpenI.instance.settings.mediadb`.
  final String? baseUrl;
  final Dio _dio;

  String get _mediadb {
    var base = (baseUrl ?? OpenI.instance?.settings.mediadb ?? '').trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.isEmpty) {
      throw const LeadServiceException('No server URL configured');
    }
    return base;
  }

  String get _base => '$_mediadb/services/module/lead';

  Options _options([LeadSession? session]) => Options(
    headers: {
      'Content-Type': 'application/json',
      'X-tokentype': 'entermedia',
      if (session != null) ...{
        'Authorization': 'Bearer ${session.token}',
        'entermediakey': session.token,
      },
    },
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  );

  Map<String, dynamic> _decode(Response response, String op) {
    final status = response.statusCode ?? 0;
    dynamic data = response.data;
    if (data is String && data.trim().isNotEmpty) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        throw LeadServiceException(
          '$op: response is not JSON',
          statusCode: status,
        );
      }
    }
    if (status < 200 || status >= 300) {
      final serverMessage = data is Map
          ? data['error'] ?? data['message']
          : null;
      throw LeadServiceException(
        '$op failed: HTTP $status${serverMessage != null ? ' ($serverMessage)' : ''}',
        statusCode: status,
      );
    }
    if (data is Map) {
      // EnterMedia templates report failures as HTTP 200 with
      // {"response": {"status": "error", "error": "..."}}.
      final meta = data['response'];
      if (meta is Map && meta['status']?.toString() == 'error') {
        throw LeadServiceException(
          '$op failed: ${meta['error'] ?? 'server error'}',
          statusCode: status,
        );
      }
      return Map<String, dynamic>.from(data);
    }
    if (data == null || (data is String && data.trim().isEmpty)) return {};
    throw LeadServiceException('$op: unexpected response shape');
  }

  Map<String, dynamic> _object(
    Map<String, dynamic> body,
    String key,
    String op,
  ) {
    final value = body[key] ?? body['data'];
    if (value is Map) return Map<String, dynamic>.from(value);
    throw LeadServiceException('$op: missing "$key" in response');
  }

  @override
  Future<VendorModel> fetchVendor(String urlName) async {
    const op = 'fetchVendor';
    final response = await _dio.get(
      '$_mediadb/services/module/librarycollection/vendor.json',
      queryParameters: {'urlname': urlName},
      options: _options(),
    );
    final vendor = VendorModel.fromJson(
      _object(_decode(response, op), 'vendor', op),
    );
    if (vendor.id.isEmpty) {
      throw const LeadServiceException('$op: vendor has no id');
    }
    return vendor;
  }

  @override
  Future<LeadQuestionnaire> fetchQuestionnaire(String vendorId) async {
    const op = 'fetchQuestionnaire';
    final response = await _dio.get(
      '$_base/questionnaire.json',
      queryParameters: {'vendorid': vendorId},
      options: _options(),
    );
    final q = LeadQuestionnaire.fromJson(
      _object(_decode(response, op), 'questionnaire', op),
    );
    if (q.id.isEmpty) {
      throw const LeadServiceException('$op: questionnaire has no id');
    }
    return q;
  }

  @override
  Future<LeadSession> startLead({
    required String vendorId,
    required String questionnaireId,
    required String name,
    required String email,
  }) async {
    const op = 'startLead';
    final response = await _dio.post(
      '$_base/startlead.json',
      data: {
        'vendorid': vendorId,
        'questionnaireid': questionnaireId,
        'name': name,
        'email': email,
      },
      options: _options(),
    );
    final session = LeadSession.fromJson(
      _object(_decode(response, op), 'lead', op),
    );
    if (!session.isValid) {
      throw const LeadServiceException(
        '$op: lead is missing leadid, userid, token or channel',
      );
    }
    return session;
  }

  @override
  Future<void> saveAnswer(
    LeadSession session, {
    required String questionId,
    required dynamic value,
  }) async {
    final response = await _dio.post(
      '$_base/answer.json',
      data: {
        'leadid': session.leadId,
        'questionid': questionId,
        'value': value,
      },
      options: _options(session),
    );
    _decode(response, 'saveAnswer');
  }

  @override
  Future<String?> completeLead(
    LeadSession session, {
    required bool consent,
  }) async {
    final response = await _dio.post(
      '$_base/complete.json',
      data: {'leadid': session.leadId, 'consent': consent},
      options: _options(session),
    );
    final body = _decode(response, 'completeLead');
    final thanks = body['thankyou']?.toString().trim();
    return (thanks == null || thanks.isEmpty) ? null : thanks;
  }

  @override
  Future<List<ChatMessage>> fetchMessages(LeadSession session) async {
    const op = 'fetchMessages';
    final response = await _dio.get(
      '$_base/messages.json',
      queryParameters: {'leadid': session.leadId},
      options: _options(session),
    );
    final body = _decode(response, op);
    final list = body['messages'] ?? body['results'] ?? body['data'];
    if (list is! List) {
      throw const LeadServiceException('$op: missing "messages" in response');
    }
    final messages =
        list
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    debugPrint('[LeadService] fetched ${messages.length} messages');
    return messages;
  }
}
