import 'chat_model.dart';

/// One session of a chat: a channel. A chat opens in its latest session (the
/// newest `refreshdate`). When that session has been idle for
/// [chatSessionIdleLimit] the app asks whether to continue it or start a new
/// one; older sessions stay reachable from the chat's Session History.
class ChatSession {
  final String channelId;
  final String name;
  final String lastMessage;
  final DateTime? refreshDate;

  const ChatSession({
    required this.channelId,
    this.name = '',
    this.lastMessage = '',
    this.refreshDate,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final last = json['lastmessage'];
    return ChatSession(
      channelId: (json['channel'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      lastMessage: last is Map
          ? (last['message'] ?? '').toString()
          : (last ?? '').toString(),
      refreshDate: _parseDate(json['refreshdate']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = value.toString();
    final millis = int.tryParse(text);
    return millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis)
        : DateTime.tryParse(text);
  }
}

/// How long a session can sit unused before the app asks whether to
/// continue it or start a new one.
const chatSessionIdleLimit = Duration(hours: 1);

/// When the conversation in [messages] last had activity, ignoring system
/// messages; null when there is none.
DateTime? lastChatActivity(Iterable<ChatMessage> messages) {
  DateTime? latest;
  for (final message in messages) {
    if (message.messageType == 'system') continue;
    if (latest == null || message.createdAt.isAfter(latest)) {
      latest = message.createdAt;
    }
  }
  return latest;
}

/// The time of the last activity when it is older than [chatSessionIdleLimit],
/// i.e. the session is worth asking about; null for an empty or recent one.
DateTime? idleSince(Iterable<ChatMessage> messages, {DateTime? now}) {
  final last = lastChatActivity(messages);
  if (last == null) return null;
  return (now ?? DateTime.now()).difference(last) > chatSessionIdleLimit
      ? last
      : null;
}
