import 'dart:convert';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../utils/error_handler.dart';
import 'product_message_model.dart';

/// Conversation / Thread Model representing chat items in list views
class ChatModel {
  final String id;
  final String userName;
  final String userRole;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;
  final String? avatarInitials;

  const ChatModel({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.avatarColor,
    this.isOnline = false,
    this.avatarInitials,
  });

  ChatModel copyWith({
    String? id,
    String? userName,
    String? userRole,
    String? lastMessage,
    String? time,
    int? unreadCount,
    Color? avatarColor,
    bool? isOnline,
    String? avatarInitials,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarColor: avatarColor ?? this.avatarColor,
      isOnline: isOnline ?? this.isOnline,
      avatarInitials: avatarInitials ?? this.avatarInitials,
    );
  }

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      time: json['time'] as String? ?? '',
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      avatarColor: json['avatarColor'] != null
          ? Color(json['avatarColor'] as int)
          : const Color(0xFF2563EB),
      isOnline: json['isOnline'] as bool? ?? false,
      avatarInitials: json['avatarInitials'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'userRole': userRole,
      'lastMessage': lastMessage,
      'time': time,
      'unreadCount': unreadCount,
      'avatarColor': avatarColor.toARGB32(),
      'isOnline': isOnline,
      if (avatarInitials != null) 'avatarInitials': avatarInitials,
    };
  }
}

/// Enum determining how a chat message should be rendered in UI
enum MessageRenderType {
  welcome,
  text,
  question,
  answer,
  answereval,
  asset,
  usercomment,
  end,
  agentcomment,
  progressupdate,
  product;

  bool get isQuestion => this == MessageRenderType.question;
  bool get isAsset => this == MessageRenderType.asset;
  bool get isWelcome => this == MessageRenderType.welcome;
  bool get isText => this == MessageRenderType.text;
  bool get isAnswer => this == MessageRenderType.answer;
  bool get isAnswerEval => this == MessageRenderType.answereval;
  bool get isUserComment => this == MessageRenderType.usercomment;
  bool get isEnd => this == MessageRenderType.end;
  bool get isAgentComment => this == MessageRenderType.agentcomment;
  bool get isProgressUpdate => this == MessageRenderType.progressupdate;
  bool get isProduct => this == MessageRenderType.product;

  factory MessageRenderType.fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return MessageRenderType.text;
    }
    final clean = name.toLowerCase().trim();
    if (clean == 'product' ||
        clean == 'ecommerce' ||
        clean == 'rideshare' ||
        clean == 'rental') {
      return MessageRenderType.product;
    }
    return MessageRenderType.values.firstWhere(
      (element) => element.name.toLowerCase() == clean,
      orElse: () => MessageRenderType.text,
    );
  }
}

class AgentContextValues {
  final MessageRenderType messageRenderType;
  final String? tutorialId;
  final String? sectionId;
  final String? componentId;
  final String? componentType;
  final String? componentContent;
  final bool? isCorrect;
  final Question? question;
  final Asset? asset;
  final ProgressUpdate? progressUpdate;
  final ProductMessageModel? product;
  bool? interactive = false;

  AgentContextValues({
    this.messageRenderType = MessageRenderType.text,
    this.tutorialId = "",
    this.sectionId = "",
    this.componentId = "",
    this.componentType,
    this.componentContent = "",
    this.isCorrect,
    this.question,
    this.asset,
    this.progressUpdate,
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
      product = ProductMessageModel.fromJson(json['product'] as Map<String, dynamic>);
      messageRenderType = MessageRenderType.product;
    } else if (json['productmessagemodel'] != null && json['productmessagemodel'] is Map<String, dynamic>) {
      product = ProductMessageModel.fromJson(json['productmessagemodel'] as Map<String, dynamic>);
      messageRenderType = MessageRenderType.product;
    }

    return AgentContextValues(
      messageRenderType: messageRenderType,
      tutorialId: json['tutorialid']?.toString(),
      sectionId: json['sectionid']?.toString(),
      componentId: json['componentid']?.toString(),
      componentType: json['componenttype']?.toString(),
      componentContent: json['componentcontent']?.toString(),
      isCorrect: bool.tryParse(json['iscorrect']?.toString() ?? ''),
      question: json['question'] != null
          ? Question.fromJson(json['question'])
          : null,
      asset: json['asset'] != null ? Asset.fromJson(json['asset']) : null,
      progressUpdate: json['progressUpdate'] != null || json['progressupdate'] != null
          ? ProgressUpdate.fromJson(json['progressUpdate'] ?? json['progressupdate'])
          : (messageRenderType == MessageRenderType.progressupdate
                ? ProgressUpdate.fromJson(json)
                : null),
      product: product,
      interactive: json['interactive'] == "yes" || json['interactive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messagerendertype': messageRenderType.name,
      'tutorialid': tutorialId,
      'sectionid': sectionId,
      'componentid': componentId,
      'componenttype': componentType,
      'componentcontent': componentContent,
      if (isCorrect != null) 'iscorrect': isCorrect!.toString(),
      if (question != null) 'question': question?.toJson(),
      if (asset != null) 'asset': asset?.toJson(),
      if (progressUpdate != null) 'progressupdate': progressUpdate?.toJson(),
      if (product != null) 'product': product?.toJson(),
      'interactive': interactive == true ? "yes" : "no",
    };
  }

  String? get text {
    if (messageRenderType.isQuestion && question != null) {
      return question!.question;
    }
    return componentContent;
  }
}

class ChatMessage {
  final String messageId;
  final String channel;
  final String userId;
  final String? message;
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
    required this.createdAt,
    this.agentContextValues,
    this.product,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // parse date
    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['date'] ?? json['createdat'];
    if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now().toLocal();
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
      if (rawAgentContext is Map<String, dynamic>) {
        decodedContext = rawAgentContext;
      } else {
        try {
          final decoded = jsonDecode(rawAgentContext.toString());
          if (decoded is Map<String, dynamic>) {
            decodedContext = decoded;
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
    AgentContextValues agentContextValues = AgentContextValues.fromJson(
      decodedContext,
    );

    // parse product
    ProductMessageModel? parsedProduct;
    if (json['product'] != null && json['product'] is Map<String, dynamic>) {
      parsedProduct = ProductMessageModel.fromJson(json['product'] as Map<String, dynamic>);
    } else {
      parsedProduct = agentContextValues.product;
    }

    final rawMessageType = json['messagetype']?.toString() ??
        (parsedProduct != null ? 'product' : 'message');

    return ChatMessage(
      messageId: (json['messageid'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      channel: (json['channel'] ?? '').toString(),
      userId: (json['user'] ?? json['userid'] ?? '').toString(),
      message: json['message']?.toString() ?? '',
      command: json['command']?.toString(),
      replyToId: (json['replytoid'] ?? json['replyToId'])?.toString(),
      messageType: rawMessageType,
      createdAt: parsedCreatedAt,
      agentContextValues: agentContextValues,
      product: parsedProduct,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'messageid': messageId,
      'channel': channel,
      'userid': userId,
      if (message != null) 'message': message,
      if (command != null) 'command': command,
      if (replyToId != null) 'replytoid': replyToId,
      if (messageType != null) 'messagetype': messageType,
      'createdat': createdAt.toIso8601String(),
      'agentcontextvalues': agentContextValues?.toJson(),
      if (product != null) 'product': product?.toJson(),
    };
    return map;
  }

  bool get isMessageRemoved => command == 'messageremoved';
  bool get isKeepAlive => command == 'keepalive';

  String get text {
    final textContent = agentContextValues?.text;
    if (textContent != null && textContent.isNotEmpty) return textContent;
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
    if (product != null || messageType == 'product') {
      return MessageRenderType.product;
    }
    if (contextValues.product != null) {
      return MessageRenderType.product;
    }
    if (contextValues.messageRenderType != MessageRenderType.text) {
      return contextValues.messageRenderType;
    }
    if (messageType != null && messageType != 'message') {
      return MessageRenderType.fromName(messageType);
    }
    return MessageRenderType.text;
  }

  Question? get question => contextValues.question;
  Answer? get answer => question?.answer;
  set answer(Answer? newAnswer) {
    if (question != null) {
      question!.answer = newAnswer;
    }
  }

  Asset? get asset => contextValues.asset;
  String? get tutorialId => contextValues.tutorialId;
  String? get sectionId => contextValues.sectionId;
  String? get componentId => contextValues.componentId;
  String? get componentType => contextValues.componentType;
  String? get textContent => contextValues.componentContent;
  ProgressUpdate? get progressUpdate => contextValues.progressUpdate;
  bool? get isCorrect => contextValues.isCorrect;
  bool get interactive => contextValues.interactive ?? false;
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
      createdAt: createdAt ?? this.createdAt,
      agentContextValues: agentContextValues ?? this.agentContextValues,
      product: product ?? this.product,
    );
  }
}

class Question {
  final String id;
  final String question;
  final Map<OptionsKey, String> options;
  final String cognitiveLevel;
  Answer? answer;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.cognitiveLevel,
    this.answer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = json['options'] as Map<String, dynamic>? ?? {};
    final mappedOptions = <OptionsKey, String>{};
    options.forEach((key, value) {
      if (value != null &&
          value.toString() != 'null' &&
          value.toString().trim().isNotEmpty) {
        mappedOptions[OptionsKey.fromString(key)] = value.toString();
      }
    });

    final sortedOptions = Map.fromEntries(
      mappedOptions.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );

    return Question(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      options: sortedOptions,
      cognitiveLevel: (json['mcqcognitivelevel'] ?? json['cognitivelevel'] ?? '').toString(),
      answer: json['answer'] != null ? Answer.fromJson(json['answer']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((k, v) => MapEntry(k.toStr(), v)),
      'cognitivelevel': cognitiveLevel,
      'answer': answer?.toJson(),
    };
  }
}

enum OptionsKey {
  optionA,
  optionB,
  optionC,
  optionD,
  optionE,
  optionF;

  factory OptionsKey.fromString(String key) {
    switch (key.toLowerCase()) {
      case 'option_a':
      case 'a':
        return OptionsKey.optionA;
      case 'option_b':
      case 'b':
        return OptionsKey.optionB;
      case 'option_c':
      case 'c':
        return OptionsKey.optionC;
      case 'option_d':
      case 'd':
        return OptionsKey.optionD;
      case 'option_e':
      case 'e':
        return OptionsKey.optionE;
      case 'option_f':
      case 'f':
        return OptionsKey.optionF;
      default:
        return OptionsKey.optionA;
    }
  }

  String toStr() {
    switch (this) {
      case OptionsKey.optionA:
        return 'option_a';
      case OptionsKey.optionB:
        return 'option_b';
      case OptionsKey.optionC:
        return 'option_c';
      case OptionsKey.optionD:
        return 'option_d';
      case OptionsKey.optionE:
        return 'option_e';
      case OptionsKey.optionF:
        return 'option_f';
    }
  }

  String get letter => toStr().split('_').last.toUpperCase();
}

enum Confidence {
  noidea,
  notsure,
  mostlysure,
  confident;

  factory Confidence.fromStr(String key) {
    switch (key.toLowerCase()) {
      case 'noidea':
      case 'no_idea':
        return Confidence.noidea;
      case 'notsure':
      case 'not_sure':
        return Confidence.notsure;
      case 'mostlysure':
      case 'mostly_sure':
        return Confidence.mostlysure;
      case 'confident':
        return Confidence.confident;
      default:
        return Confidence.confident;
    }
  }

  String getLabel([dynamic l10n]) {
    if (l10n != null) {
      try {
        switch (this) {
          case Confidence.noidea:
            return (l10n.noIdea as String?) ?? 'No Idea';
          case Confidence.notsure:
            return (l10n.notSure as String?) ?? 'Not Sure';
          case Confidence.mostlysure:
            return (l10n.mostlySure as String?) ?? 'Mostly Sure';
          case Confidence.confident:
            return (l10n.confident as String?) ?? 'Confident';
        }
      } catch (_) {}
    }
    switch (this) {
      case Confidence.noidea:
        return 'No Idea';
      case Confidence.notsure:
        return 'Not Sure';
      case Confidence.mostlysure:
        return 'Mostly Sure';
      case Confidence.confident:
        return 'Confident';
    }
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

class Answer {
  OptionsKey? selectedOption;
  Confidence? confidence;
  bool? isCorrect;

  void setSelectedOption(OptionsKey option) {
    selectedOption = option;
  }

  void setConfidence(Confidence confidence) {
    this.confidence = confidence;
  }

  Answer({this.selectedOption, this.confidence, this.isCorrect});

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      selectedOption: json['selectedoption'] != null
          ? OptionsKey.fromString(json['selectedoption'])
          : null,
      confidence: json['confidence'] != null
          ? Confidence.fromStr(json['confidence'])
          : null,
      isCorrect: bool.tryParse(json['iscorrect']?.toString() ?? '') ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedoption': selectedOption?.toStr(),
      'confidence': confidence?.name,
      'iscorrect': isCorrect,
    };
  }
}

class ProgressUpdate {
  final double beginnerProgress;
  final double competentProgress;
  final double expertProgress;

  ProgressUpdate({
    required this.beginnerProgress,
    required this.competentProgress,
    required this.expertProgress,
  });

  factory ProgressUpdate.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ProgressUpdate(
      beginnerProgress: parseDouble(json['beginnerprogress']),
      competentProgress: parseDouble(json['competentprogress']),
      expertProgress: parseDouble(json['expertprogress']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'beginnerprogress': beginnerProgress,
      'competentprogress': competentProgress,
      'expertprogress': expertProgress,
    };
  }
}
