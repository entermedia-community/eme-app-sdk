import 'chat_model.dart';

/// What [mergeChatMessage] did with a message that came in over the socket.
enum ChatMergeOutcome {
  /// A new message was added to the list.
  added,

  /// A message already in the list changed (a patch, a re-sent message).
  updated,

  /// A message was taken out of the list.
  removed,

  /// Nothing to do: a keepalive, a patch seen before, or one that can't be
  /// applied until the message is replaced whole.
  ignored,

  /// A patch was missed. The caller should load the chat history again.
  needsReload,
}

/// Applies one message from the socket to [messages], the list a chat shows.
///
/// - `messageremoved` takes the message out.
/// - `messageappend` adds its ops to the end of the message with that id, and
///   `messagereplace` swaps them. Patches carry a `seq`; an append whose number
///   skips one means the ops in between were lost, so the result is
///   [ChatMergeOutcome.needsReload]. A replace holds the whole message, so a
///   skipped number does not matter to it.
/// - Anything else is a whole message: it replaces the one with the same id, or
///   is added if there is none. The server sends the finished message this way
///   after its patches, which also puts a client that missed some right again.
///
/// An append can only be applied to a message this client has followed from a
/// patch (it knows the `seq` of). One loaded from history (a snapshot saved
/// midway) has no number, so appends to it are ignored until a replace or the
/// finished message arrives. Reloading on those would just reload on every
/// patch.
ChatMergeOutcome mergeChatMessage(
  List<ChatMessage> messages,
  ChatMessage incoming,
) {
  if (incoming.isKeepAlive) return ChatMergeOutcome.ignored;

  final index = messages.indexWhere((m) => m.messageId == incoming.messageId);

  if (incoming.isMessageRemoved) {
    if (index < 0) return ChatMergeOutcome.ignored;
    messages.removeAt(index);
    return ChatMergeOutcome.removed;
  }

  if (!incoming.isPatch) {
    if (index < 0) {
      messages.add(incoming);
      return ChatMergeOutcome.added;
    }
    messages[index] = incoming;
    return ChatMergeOutcome.updated;
  }

  final seq = incoming.seq;
  if (index < 0) {
    // A replace is the whole message, so it can start one. An append has
    // nothing to add to.
    if (incoming.isReplace) {
      messages.add(
        ChatMessage(
          messageId: incoming.messageId,
          channel: incoming.channel,
          userId: incoming.userId,
          message: incoming.message,
          seq: seq,
          messageType: incoming.messageType,
          deltaOps: incoming.deltaOps,
          createdAt: incoming.createdAt,
          agentContextValues: incoming.agentContextValues,
        ),
      );
      return ChatMergeOutcome.added;
    }
    return ChatMergeOutcome.needsReload;
  }

  final existing = messages[index];
  final last = existing.seq;
  if (seq != null && last != null && seq <= last) {
    return ChatMergeOutcome.ignored; // already applied
  }
  if (incoming.isAppend && seq != null) {
    if (last == null) return ChatMergeOutcome.ignored;
    if (seq > last + 1) return ChatMergeOutcome.needsReload;
  }
  messages[index] = existing.applyPatch(incoming);
  return ChatMergeOutcome.updated;
}
