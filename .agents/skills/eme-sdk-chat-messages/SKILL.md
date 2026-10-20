---
name: eme-sdk-chat-messages
description: How chat messages are parsed, typed and sent in eme_app_sdk — ChatMessage.fromJson, MessageRenderType (text/welcome/form/asset/delta/product), agentcontextvalues, FormField, and the ChatSocketService WebSocket protocol. Use when adding a new message type, changing how server/agent replies are parsed, sending a new kind of payload (form submit, product, command), or debugging why a message renders as the wrong bubble.
---

# EME chat messages and the socket protocol

## Where things are

- `lib/models/chat_model.dart` — `ChatMessage`, `MessageRenderType`, `AgentContextValues`, `Asset`, `ChatModel`
- `lib/models/form_model.dart` — `FormField`, `FormFieldType` (`text, number, boolean, select, radio, checkbox`), `FormFieldOption`
- `lib/models/product_message_model.dart` — `ProductMessageModel`, `ProductType`
- `lib/services/chat_socket_service.dart` — WebSocket connect/send/receive

## Incoming JSON → ChatMessage

The socket and the history endpoints both produce `ChatMessage.fromJson`. Main keys:

| JSON key | Field | Notes |
|---|---|---|
| `messageid`, `channel`, `user` | `messageId`, `channel`, `userId` | `isUser` is true when `userId == AuthService.userId` (or `'user'`/`'me'`) |
| `message` | `message` | May be plain text **or** a JSON string/map containing `ops`/`delta` (Quill) or `form` |
| `date` / `createdat` | `createdAt` | ISO string or epoch millis |
| `command` | `command` | `messagereceived`, `keepalive`, `messageremoved` |
| `messagetype` | `messageType` | e.g. `message`, `product`, `asset` |
| `agentcontextvalues` | `agentContextValues` | Map or JSON string: `messagerendertype`, `form`/`formfields`/`fields`, `asset`, `product`, `interactive` |
| `form`, `messagerendertype` (root) | merged into context | Root-level values are supported as a fallback |

The `messageRenderType` getter picks the bubble in this order: product → asset → (delta ops / form
fields / context type) → text. Providing form fields forces `form`.

## Adding a new MessageRenderType

1. Add the value to `enum MessageRenderType` and an `isXxx` getter.
2. Parse the payload it needs in `AgentContextValues.fromJson` and/or `ChatMessage.fromJson`, and
   add a field to `ChatMessage` (+ `toJson`).
3. Update the `messageRenderType` getter if detection isn't just `messagerendertype: "xxx"`.
4. Add a parsing test in `test/sdk_test.dart` using a real sample payload from the server.
5. **The app's render switches are exhaustive** — `flutter analyze` in `eme-app-profile` will
   flag both of them:
   - `lib/screens/chats/chat_detail_screen.dart` → `_buildMessageContent`
   - `lib/screens/server/tabs/server_chat_tab.dart` → `_buildMessageContent`
   Follow the `eme-app-chat-ui` skill in that repo to add the bubble.

Unknown names fall back to `text` via `MessageRenderType.fromName`. That fallback is intended,
so don't add more silent fallbacks for unrecognized structured payloads. Surface them so they can
be fixed.

## Outgoing: ChatSocketService

```dart
final socket = ChatSocketService();            // singleton
final channel = await socket.connectChat(server.id);          // server chat
// or: await socket.connectUser(fromUser: me, toUser: them);  // DM
await socket.connect(channel: channel, userId: AuthService.userId,
    baseUrl: server.serverMediaDBUrl.isNotEmpty ? server.serverMediaDBUrl : null);
final sub = socket.messageStream.listen((m) {
  if (m.isKeepAlive || m.isMessageRemoved) return;
  if (m.channel.isNotEmpty && m.channel != channel) return; // singleton: filter!
  ...
});
socket.sendMessage(message: text, user: AuthService.userId!, channel: channel,
    messageType: 'message', extraData: {...});
```

- `sendMessage` adds `catalogid`, `command` (default `messagereceived`), `replytoid`,
  `functionname`, `nextfunctionname`, `messagetype`. Anything else goes in `extraData`
  (e.g. `product`, `agentcontextvalues`, form answers).
- `sendRaw` **drops the message with only a debugPrint if the socket isn't connected**. If a
  feature needs delivery guarantees, add a return value or exception instead of relying on it silently.
- `connectChat(serverId, params: {...})` POSTs to `services/chat/connect.json` and is also how
  form submissions are sent to a server (see `ServerChatTab`).
- Keep-alive runs every 20s and reconnect is automatic. Call `disconnect()` only when leaving chat entirely.

## Verify

```bash
cd ../eme-app-sdk && flutter test
cd ../eme-app-profile && flutter analyze && flutter test test/chat_detail_test.dart test/form_select_widget_test.dart test/product_message_test.dart
```
