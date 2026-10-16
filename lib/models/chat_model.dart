import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../utils/error_handler.dart';
import 'product_message_model.dart';

/// Conversation / Thread Model representing chat items in list views
class ChatModel {
  final String? channelId;
  final String username;
  final String displayName;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;
  final String? avatarInitials;
  final String? avatarUrl;

  const ChatModel({
    this.channelId,
    required this.username,
    required this.displayName,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.avatarColor,
    this.isOnline = false,
    this.avatarInitials,
    this.avatarUrl,
  });

  ChatModel copyWith({
    String? channelId,
    String? username,
    String? displayName,
    String? lastMessage,
    String? time,
    int? unreadCount,
    Color? avatarColor,
    bool? isOnline,
    String? avatarInitials,
    String? avatarUrl,
  }) {
    return ChatModel(
      channelId: channelId ?? this.channelId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarColor: avatarColor ?? this.avatarColor,
      isOnline: isOnline ?? this.isOnline,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final rawFirst = json['firstname'].toString();
    final rawLast = json['lastname'].toString();
    final displayName = '$rawFirst $rawLast'.trim();

    final rawLastMsg = json['lastmessage'];
    String lastMsgText = '';
    String timeText = '';
    if (rawLastMsg is Map<String, dynamic>) {
      lastMsgText = rawLastMsg['message']?.toString() ?? '';
      timeText = formatChatDate(rawLastMsg['date']);
    } else if (rawLastMsg is String) {
      lastMsgText = rawLastMsg;
    }
    if (lastMsgText.isEmpty) {
      lastMsgText = json['lastMessage']?.toString() ?? '';
    }

    final unread =
        (json['unreadmessagecount'] ?? json['unreadCount'] as num?)?.toInt() ??
        0;

    final portrait = (json['assetportrait'])?.toString();

    final initials =
        json['avatarInitials'] as String? ??
        (displayName.isNotEmpty
            ? displayName
                  .trim()
                  .split(RegExp(r'\s+'))
                  .take(2)
                  .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
                  .join()
            : null);

    final colorInt = json['avatarColor'] as int?;
    final color = colorInt != null
        ? Color(colorInt)
        : _generateColor(displayName);

    return ChatModel(
      channelId: json['channel'],
      username: json['username'],
      displayName: displayName,
      lastMessage: lastMsgText,
      time: timeText,
      unreadCount: unread,
      avatarColor: color,
      isOnline: json['isOnline'] as bool? ?? false,
      avatarInitials: initials,
      avatarUrl: portrait,
    );
  }

  static Color _generateColor(String key) {
    const colors = [
      Color(0xFF0284C7),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
      Color(0xFF14B8A6),
    ];
    if (key.isEmpty) return colors[0];
    return colors[key.hashCode.abs() % colors.length];
  }

  static String formatChatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    if (dateVal is DateTime) {
      return _formatDateTime(dateVal);
    }
    final str = dateVal.toString().trim();
    if (str.isEmpty || str == 'null') return '';

    final numVal = num.tryParse(str);
    if (numVal != null) {
      try {
        final millis = numVal > 100000000000
            ? numVal.toInt()
            : (numVal * 1000).toInt();
        return _formatDateTime(DateTime.fromMillisecondsSinceEpoch(millis));
      } catch (_) {}
    }

    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return _formatDateTime(parsed);
    }

    return str;
  }

  static String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inDays == 0 && now.day == local.day) {
      final hour = local.hour > 12
          ? local.hour - 12
          : (local.hour == 0 ? 12 : local.hour);
      final period = local.hour >= 12 ? 'PM' : 'AM';
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    } else if (diff.inDays == 1 || (diff.inDays < 2 && now.day != local.day)) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[local.weekday - 1];
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[local.month - 1]} ${local.day}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'channel': channelId,
      'username': username,
      'displayName': displayName,
      'lastMessage': lastMessage,
      'time': time,
      'unreadCount': unreadCount,
      'avatarColor': avatarColor.toARGB32(),
      'isOnline': isOnline,
      if (avatarInitials != null) 'avatarInitials': avatarInitials,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
}

/// Enum determining how a chat message should be rendered in UI
enum MessageRenderType {
  welcome,
  text,
  form,
  asset,
  delta,
  product;

  bool get isAsset => this == MessageRenderType.asset;
  bool get isWelcome => this == MessageRenderType.welcome;
  bool get isText => this == MessageRenderType.text;
  bool get isDelta => this == MessageRenderType.delta;
  bool get isProduct => this == MessageRenderType.product;
  bool get isForm => this == MessageRenderType.form;

  factory MessageRenderType.fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return MessageRenderType.text;
    }
    final clean = name.toLowerCase().trim();
    return MessageRenderType.values.firstWhere(
      (element) => element.name.toLowerCase() == clean,
      orElse: () => MessageRenderType.text,
    );
  }
}

class FormFieldOption {
  final dynamic value;
  final String label;

  FormFieldOption({required this.value, required this.label});
  factory FormFieldOption.fromJson(Map<String, dynamic> json) {
    return FormFieldOption(
      value: json['value'],
      label: (json['label'] ?? json['name'] ?? json['value'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'value': value, 'label': label};
  }
}

enum FormFieldType {
  text,
  number,
  boolean,
  select,
  radio,
  checkbox;

  factory FormFieldType.fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return FormFieldType.text;
    }
    final clean = name.toLowerCase().trim();
    return FormFieldType.values.firstWhere(
      (element) => element.name.toLowerCase() == clean,
      orElse: () => FormFieldType.text,
    );
  }
}

class FormField {
  final String name;
  final FormFieldType type;
  final String label;
  final dynamic value;
  final List<FormFieldOption> options;
  final bool? readOnly;

  FormField({
    required this.name,
    required this.type,
    required this.label,
    this.value,
    this.options = const [],
    this.readOnly = false,
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    final rawReadOnly = json['readOnly'] ?? json['readonly'];
    final rawOptions = json['options'] ?? [];
    List<FormFieldOption> options = [];
    if (rawOptions is List) {
      for (var item in rawOptions) {
        if (item is Map) {
          options.add(
            FormFieldOption.fromJson(Map<String, dynamic>.from(item)),
          );
        } else if (item != null) {
          options.add(FormFieldOption(value: item, label: item.toString()));
        }
      }
    }
    return FormField(
      name: (json['name'] ?? '').toString(),
      type: FormFieldType.fromName(json['type']),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      value: json['value'],
      options: options,
      readOnly: rawReadOnly == true || rawReadOnly == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'label': label,
      'value': value,
      'options': options.map((e) => e.toJson()).toList(),
      'readOnly': readOnly,
    };
  }

  FormField copyWith({
    String? name,
    FormFieldType? type,
    String? label,
    dynamic value,
    List<FormFieldOption>? options,
    bool? readOnly,
  }) {
    return FormField(
      name: name ?? this.name,
      type: type ?? this.type,
      label: label ?? this.label,
      value: value ?? this.value,
      options: options ?? this.options,
      readOnly: readOnly ?? this.readOnly,
    );
  }
}

class AgentContextValues {
  final MessageRenderType messageRenderType;
  final String? content;
  final Asset? asset;
  final ProductMessageModel? product;
  bool? interactive = false;

  AgentContextValues({
    this.messageRenderType = MessageRenderType.text,
    this.content,
    this.asset,
    this.product,
    this.interactive = false,
  });

  void setInteractive(bool interactive) {
    this.interactive = interactive;
  }

  factory AgentContextValues.fromJson(Map<String, dynamic> json) {
    String? rawMessageRenderType = json['messagerendertype']
        ?.toString()
        .toLowerCase();

    var messageRenderType = MessageRenderType.fromName(rawMessageRenderType);

    ProductMessageModel? product;
    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      product = ProductMessageModel.fromJson(
        json['product'] as Map<String, dynamic>,
      );
    }

    List<FormField> formFields = [];

    dynamic rawForm = json['form'] ?? json['formfields'] ?? json['fields'];
    if (rawForm is String && rawForm.trim().isNotEmpty) {
      try {
        rawForm = jsonDecode(rawForm);
      } catch (_) {}
    }

    if (rawForm is List) {
      for (var item in rawForm) {
        if (item is Map) {
          formFields.add(FormField.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    if (formFields.isNotEmpty &&
        (messageRenderType == MessageRenderType.text ||
            messageRenderType.isForm)) {
      messageRenderType = MessageRenderType.form;
    }

    return AgentContextValues(
      messageRenderType: messageRenderType,
      asset: json['asset'] != null ? Asset.fromJson(json['asset']) : null,
      product: product,
      interactive:
          formFields.isNotEmpty ||
          json['interactive'] == "yes" ||
          json['interactive'] == true,
    );
  }
}

class ChatMessage {
  final String messageId;
  final String channel;
  final String userId;
  final String? message;
  final List<dynamic> deltaOps;
  final List<FormField> formFields;
  final String? command;
  final String? replyToId;
  final String? messageType;
  final DateTime createdAt;
  final AgentContextValues? agentContextValues;
  final ProductMessageModel? product;

  ChatMessage({
    required this.messageId,
    required this.channel,
    required this.userId,
    this.message,
    this.command,
    this.replyToId,
    this.messageType = 'message',
    List<dynamic>? deltaOps,
    List<FormField>? formFields,
    required this.createdAt,
    this.agentContextValues,
    this.product,
  }) : deltaOps = (deltaOps != null && deltaOps.isNotEmpty)
           ? deltaOps
           : (deltaOps ?? const []),
       formFields = (formFields != null && formFields.isNotEmpty)
           ? formFields
           : (formFields ?? const []);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // parse date
    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['date'] ?? json['createdat'];
    if (rawCreatedAt is String) {
      parsedCreatedAt =
          DateTime.tryParse(rawCreatedAt)?.toLocal() ??
          DateTime.now().toLocal();
    } else if (rawCreatedAt is num) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(
        rawCreatedAt.toInt(),
      ).toLocal();
    } else {
      parsedCreatedAt = DateTime.now().toLocal();
    }

    // decode context values
    final rawAgentContext = json['agentcontextvalues'];
    Map<String, dynamic> decodedContext = {};
    if (rawAgentContext != null &&
        rawAgentContext.toString().trim().isNotEmpty) {
      if (rawAgentContext is Map) {
        decodedContext = Map<String, dynamic>.from(rawAgentContext);
      } else {
        try {
          final decoded = jsonDecode(rawAgentContext.toString());
          if (decoded is Map) {
            decodedContext = Map<String, dynamic>.from(decoded);
          }
        } catch (e, stack) {
          debugPrint('Error decoding agentcontextvalues: $e');
          AppErrorHandler.recordNonFatal(
            e,
            stack,
            reason: 'Error decoding agentcontextvalues in ChatMessage.fromJson',
            customKeys: {'rawAgentContext': rawAgentContext.toString()},
          );
        }
      }
    }

    // Support root-level form or messagerendertype if not present in agentcontextvalues
    if (json['form'] != null && decodedContext['form'] == null) {
      decodedContext['form'] = json['form'];
    }
    if (json['messagerendertype'] != null &&
        decodedContext['messagerendertype'] == null) {
      decodedContext['messagerendertype'] = json['messagerendertype'];
    }

    // Parse message field (which may be a JSON string containing ops, form key)
    final rawMessage = json['message'];
    String? messageString;
    dynamic messageJson;

    if (rawMessage is Map) {
      messageJson = rawMessage;
      try {
        messageString = jsonEncode(rawMessage);
      } catch (_) {
        messageString = rawMessage.toString();
      }
    } else if (rawMessage != null) {
      messageString = rawMessage.toString();
      final trimmed = messageString.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          messageJson = jsonDecode(trimmed);
        } catch (_) {}
      }
    }

    List<dynamic> deltaOps = [];
    List<FormField> formFields = [];

    if (messageJson is Map) {
      // 1. Check ops/delta in message JSON
      dynamic rawOps = messageJson['ops'];
      if (rawOps is List) {
        deltaOps = List<dynamic>.from(rawOps);
      } else if (messageJson['delta'] != null) {
        dynamic rawDelta = messageJson['delta'];
        if (rawDelta is Map && rawDelta['ops'] is List) {
          deltaOps = List<dynamic>.from(rawDelta['ops']);
        } else if (rawDelta is String && rawDelta.trim().isNotEmpty) {
          try {
            final decodedDelta = jsonDecode(rawDelta);
            if (decodedDelta is Map && decodedDelta['ops'] is List) {
              deltaOps = List<dynamic>.from(decodedDelta['ops']);
            } else if (decodedDelta is List) {
              deltaOps = List<dynamic>.from(decodedDelta);
            }
          } catch (_) {}
        }
      }

      // 2. Check form in message JSON
      dynamic rawForm =
          messageJson['form'] ??
          messageJson['formfields'] ??
          messageJson['fields'];
      if (rawForm is String && rawForm.trim().isNotEmpty) {
        try {
          rawForm = jsonDecode(rawForm);
        } catch (_) {}
      }
      if (rawForm is List) {
        for (var item in rawForm) {
          if (item is Map) {
            formFields.add(FormField.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    } else if (messageJson is List) {
      if (messageJson.isNotEmpty &&
          messageJson.first is Map &&
          (messageJson.first as Map).containsKey('insert')) {
        deltaOps = List<dynamic>.from(messageJson);
      }
    }

    // Sync message json keys to decodedContext if not present
    if (formFields.isNotEmpty && decodedContext['form'] == null) {
      decodedContext['form'] = messageJson is Map ? messageJson['form'] : null;
    }
    if (deltaOps.isNotEmpty && decodedContext['delta'] == null) {
      decodedContext['delta'] = jsonEncode({'ops': deltaOps});
    }

    AgentContextValues agentContextValues = AgentContextValues.fromJson(
      decodedContext,
    );

    // parse product
    ProductMessageModel? parsedProduct;
    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      parsedProduct = ProductMessageModel.fromJson(
        json['product'] as Map<String, dynamic>,
      );
    } else {
      parsedProduct = agentContextValues.product;
    }

    final rawMessageType =
        json['messagetype']?.toString() ??
        (parsedProduct != null ? 'product' : 'message');

    return ChatMessage(
      messageId:
          (json['messageid'] ??
                  json['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .toString(),
      channel: (json['channel'] ?? '').toString(),
      userId: (json['user'] ?? json['userid'] ?? '').toString(),
      message: messageString ?? '',
      command: json['command']?.toString(),
      replyToId: (json['replytoid'] ?? json['replyToId'])?.toString(),
      messageType: rawMessageType,
      deltaOps: deltaOps,
      formFields: formFields,
      createdAt: parsedCreatedAt,
      agentContextValues: agentContextValues,
      product: parsedProduct,
    );
  }

  Map<String, dynamic> toJson() {
    String? effectiveMessage = message;
    if ((effectiveMessage == null || effectiveMessage.isEmpty) &&
        (deltaOps.isNotEmpty || formFields.isNotEmpty)) {
      final map = <String, dynamic>{};
      if (deltaOps.isNotEmpty) {
        map['ops'] = deltaOps;
      }
      if (formFields.isNotEmpty) {
        map['form'] = formFields.map((e) => e.toJson()).toList();
      }
      effectiveMessage = jsonEncode(map);
    }

    final map = <String, dynamic>{
      'messageid': messageId,
      'channel': channel,
      'userid': userId,
      'message': ?effectiveMessage,
      if (command != null) 'command': command,
      if (replyToId != null) 'replytoid': replyToId,
      if (messageType != null) 'messagetype': messageType,
      'createdat': createdAt.toIso8601String(),
      if (product != null) 'product': product?.toJson(),
    };
    return map;
  }

  bool get isMessageRemoved => command == 'messageremoved';
  bool get isKeepAlive => command == 'keepalive';

  String get text {
    if (deltaOps.isNotEmpty) {
      final textBuilder = StringBuffer();
      for (var op in deltaOps) {
        if (op is Map && op['insert'] is String) {
          textBuilder.write(op['insert']);
        }
      }
      final str = textBuilder.toString();
      if (str.isNotEmpty) return str;
    }

    if (formFields.isNotEmpty) {
      final formBuilder = StringBuffer();
      for (var field in formFields) {
        formBuilder.write('${field.label}: ${field.value}\n');
      }
      final str = formBuilder.toString();
      if (str.isNotEmpty) return str;
    }

    return message ?? '';
  }

  bool get isUser =>
      userId == 'user' ||
      userId == 'me' ||
      (AuthService.userId != null &&
          AuthService.userId!.isNotEmpty &&
          userId == AuthService.userId);
  bool get isAI => !isUser;
  String get sender => isUser ? 'user' : 'ai';

  AgentContextValues get contextValues =>
      agentContextValues ?? AgentContextValues();

  MessageRenderType get messageRenderType {
    if (product != null ||
        messageType == 'product' ||
        agentContextValues?.product != null) {
      return MessageRenderType.product;
    }
    if (messageType == 'asset' ||
        agentContextValues?.messageRenderType == MessageRenderType.asset) {
      return MessageRenderType.asset;
    }
    if (messageType == 'welcome' ||
        agentContextValues?.messageRenderType == MessageRenderType.welcome) {
      return MessageRenderType.welcome;
    }
    if (formFields.isNotEmpty ||
        messageType == 'form' ||
        agentContextValues?.messageRenderType == MessageRenderType.form) {
      return MessageRenderType.form;
    }
    if (deltaOps.isNotEmpty ||
        messageType == 'delta' ||
        agentContextValues?.messageRenderType == MessageRenderType.delta) {
      return MessageRenderType.delta;
    }
    if (agentContextValues != null &&
        agentContextValues!.messageRenderType != MessageRenderType.text) {
      return agentContextValues!.messageRenderType;
    }
    if (messageType != null && messageType != 'message') {
      return MessageRenderType.fromName(messageType);
    }
    return MessageRenderType.text;
  }

  Asset? get asset => contextValues.asset;

  bool get interactive =>
      formFields.isNotEmpty || (contextValues.interactive ?? false);
  set interactive(bool newInteractive) {
    contextValues.interactive = newInteractive;
  }

  ChatMessage copyWith({
    String? messageId,
    String? channel,
    String? userId,
    String? message,
    String? command,
    String? replyToId,
    String? messageType,
    List<dynamic>? deltaOps,
    List<FormField>? formFields,
    DateTime? createdAt,
    AgentContextValues? agentContextValues,
    ProductMessageModel? product,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      channel: channel ?? this.channel,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      command: command ?? this.command,
      replyToId: replyToId ?? this.replyToId,
      messageType: messageType ?? this.messageType,
      deltaOps: deltaOps ?? this.deltaOps,
      formFields: formFields ?? this.formFields,
      createdAt: createdAt ?? this.createdAt,
      agentContextValues: agentContextValues ?? this.agentContextValues,
      product: product ?? this.product,
    );
  }
}

class Asset {
  final String id;
  final String thumbnail;
  final String url;
  final String mediaType;

  Asset({
    required this.id,
    required this.thumbnail,
    required this.url,
    required this.mediaType,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: (json['id'] ?? '').toString(),
      thumbnail: (json['thumbnail'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      mediaType: (json['mediatype'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thumbnail': thumbnail,
      'url': url,
      'mediatype': mediaType,
    };
  }
}
