import 'form_model.dart';

bool _parseBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  if (s.isEmpty) return fallback;
  return s == 'true' || s == 'yes' || s == '1';
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// One question of a vendor's lead questionnaire, asked one at a time.
class LeadQuestion {
  final String id;
  final String prompt;
  final FormFieldType type;
  final List<FormFieldOption> options;
  final bool required;
  final String? placeholder;

  /// Preset value for [FormFieldType.hidden] questions (sent, never asked).
  final dynamic value;

  const LeadQuestion({
    required this.id,
    required this.prompt,
    this.type = FormFieldType.text,
    this.options = const [],
    this.required = false,
    this.placeholder,
    this.value,
  });

  factory LeadQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return LeadQuestion(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      prompt: (json['prompt'] ?? json['question'] ?? json['label'] ?? '')
          .toString(),
      type: FormFieldType.fromName(json['type']?.toString()),
      options: rawOptions is List
          ? rawOptions
                .whereType<Map>()
                .map(
                  (e) => FormFieldOption.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      required: _parseBool(json['required']),
      placeholder: _nonEmpty(json['placeholder']),
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'type': type.name,
    'options': options.map((e) => e.toJson()).toList(),
    'required': required,
    if (placeholder != null) 'placeholder': placeholder,
    if (value != null) 'value': value,
  };
}

/// A vendor's questionnaire: greeting, questions, consent text and the
/// closing thank-you message.
class LeadQuestionnaire {
  final String id;
  final String vendorId;
  final String? vendorName;
  final String? greeting;
  final List<LeadQuestion> questions;
  final String consentText;
  final String? thankYouMessage;

  const LeadQuestionnaire({
    required this.id,
    required this.vendorId,
    this.vendorName,
    this.greeting,
    this.questions = const [],
    required this.consentText,
    this.thankYouMessage,
  });

  factory LeadQuestionnaire.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] ?? json['fields'];
    return LeadQuestionnaire(
      id: (json['id'] ?? '').toString(),
      vendorId: (json['vendorid'] ?? json['vendorId'] ?? '').toString(),
      vendorName: _nonEmpty(json['vendorname'] ?? json['vendorName']),
      greeting: _nonEmpty(json['greeting']),
      questions: rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map((e) => LeadQuestion.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      consentText: (json['consenttext'] ?? json['consentText'] ?? '')
          .toString(),
      thankYouMessage: _nonEmpty(json['thankyou'] ?? json['thankYouMessage']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vendorid': vendorId,
    if (vendorName != null) 'vendorname': vendorName,
    if (greeting != null) 'greeting': greeting,
    'questions': questions.map((e) => e.toJson()).toList(),
    'consenttext': consentText,
    if (thankYouMessage != null) 'thankyou': thankYouMessage,
  };
}

/// The anonymous session the server hands out once a visitor gives their
/// name and email. [token] authenticates every later lead call and the chat
/// socket; [channel] is the chat channel admins reply on.
class LeadSession {
  final String leadId;
  final String userId;
  final String token;
  final String channel;

  const LeadSession({
    required this.leadId,
    required this.userId,
    required this.token,
    required this.channel,
  });

  factory LeadSession.fromJson(Map<String, dynamic> json) {
    return LeadSession(
      leadId: (json['leadid'] ?? json['id'] ?? '').toString(),
      userId: (json['userid'] ?? json['user'] ?? '').toString(),
      token: (json['token'] ?? json['entermediakey'] ?? '').toString(),
      channel: (json['channel'] ?? json['channelid'] ?? '').toString(),
    );
  }

  bool get isValid =>
      leadId.isNotEmpty &&
      userId.isNotEmpty &&
      token.isNotEmpty &&
      channel.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'leadid': leadId,
    'userid': userId,
    'token': token,
    'channel': channel,
  };
}

/// One entry of a vendor's menu: an `automationscenario` picked in
/// `librarycollection.vendorscenario`.
class VendorMenuItem {
  final String id;
  final String name;
  final String? description;

  /// Bootstrap-style icon name from `automationscenario.scenarioicon`.
  final String? icon;
  final bool chatEnabled;

  const VendorMenuItem({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.chatEnabled = false,
  });

  factory VendorMenuItem.fromJson(Map<String, dynamic> json) => VendorMenuItem(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    description: _nonEmpty(json['description'] ?? json['longcaption']),
    icon: _nonEmpty(json['icon'] ?? json['scenarioicon']),
    chatEnabled: _parseBool(json['chatenabled']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    if (icon != null) 'icon': icon,
    'chatenabled': chatEnabled,
  };
}

/// A vendor is a `librarycollection` with `collectiontype=8`, looked up by
/// its `urlname`.
class VendorModel {
  final String id;
  final String name;
  final String urlName;
  final List<VendorMenuItem> menu;

  const VendorModel({
    required this.id,
    required this.name,
    required this.urlName,
    this.menu = const [],
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    final rawMenu = json['menu'];
    return VendorModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      urlName: (json['urlname'] ?? json['urlName'] ?? '').toString(),
      menu: rawMenu is List
          ? rawMenu
                .whereType<Map>()
                .map(
                  (e) => VendorMenuItem.fromJson(Map<String, dynamic>.from(e)),
                )
                .where((m) => m.id.isNotEmpty)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'urlname': urlName,
    'menu': menu.map((e) => e.toJson()).toList(),
  };
}
