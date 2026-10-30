/// One session of a chat: a channel. A new session (channel) starts when a
/// chat is opened after a set amount of idle time, and older sessions stay
/// reachable from the chat's Session History, newest `refreshdate` first.
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
