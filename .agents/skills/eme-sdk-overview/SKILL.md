---
name: eme-sdk-overview
description: Architecture map of eme_app_sdk, the shared Dart/Flutter package behind the EME Collective Intelligence chat app (eme_world / eme-app-profile). Use before changing anything in the SDK, or when the user asks how the SDK works, where something lives, how auth/servers/chat/websockets/MCP are wired, which backend endpoints exist, or how the app talks to EME servers.
---

# EME App SDK — Overview

`eme_app_sdk` (at `../eme-app-sdk`) holds everything the EME Collective Intelligence app needs that is not UI:
models, the REST client, the chat WebSocket, auth, MCP client, and Riverpod providers. The
chat app `eme_world` (repo `eme-app-profile`) depends on it via `path: ../eme-app-sdk`, so SDK
edits show up in the app immediately — no publishing step.

Everything is re-exported from one barrel: `lib/eme_app_sdk.dart`. **When you add a new file,
add an `export` to the matching barrel** (`models/models.dart`, `providers/providers.dart`,
`auth/auth.dart`, or `eme_app_sdk.dart` for services/utils), otherwise the app can't see it.

## Layout

| Path | What lives there |
|---|---|
| `lib/openinsitute_core.dart` | `OpenI` singleton (registered with GetX). `OpenI().initialize({...})` is called in the app's `main()` with `mediadb`, `siteroot`, `catalogid`. `OpenI.instance?.settings.mediadb` is the default backend base URL. |
| `lib/utils/dio.dart` | `DioUtil.dio` — the shared Dio with a cookie jar (persistent on mobile, in-memory on web). `validateStatus` accepts every status, so **you must check `statusCode` yourself**. |
| `lib/utils/error_handler.dart` | `AppErrorHandler.recordNonFatal(e, stack, reason:, customKeys:)` → Crashlytics. |
| `lib/auth/` | `IAuthService` / `AuthService` (email + one-time-code login: `sendusercode.json`, `token.json`), `AuthState`, `authProvider`, `currentUserProvider`, `isAuthenticatedProvider`. `AuthService.userId` / `AuthService.token` are static accessors used everywhere. |
| `lib/services/api_service.dart` | `IApiService` (the contract) + `ApiService` (Dio implementation). Servers, categories, join/leave, users, profile, products, chats, chat history, files, goals, transactions, blog posts. |
| `lib/services/chat_socket_service.dart` | `ChatSocketService` singleton: `connectUser` (DM channel), `connectChat` (server channel), `connect` (WebSocket), `sendMessage`, `messageStream`, keep-alive and auto-reconnect. |
| `lib/services/mcp_client_service.dart` | JSON-RPC client for user-added MCP servers: `connectAndDiscover`, `listTools`, `callTool`, `processUserMessage`. |
| `lib/services/mcp_storage_service.dart` | Persists MCP servers + conversations in SharedPreferences. |
| `lib/services/deep_link_service.dart` | `emeworld://` links → `DeepLinkPayload` (`DeepLinkType.chat`, username, channelId). |
| `lib/services/push_notification_service.dart` | Firebase Messaging + local notifications. |
| `lib/services/oi_chat_manager.dart`, `models/oi_chat_message.dart` | Older OpenInstitute project chat (`librarycollection/*.json`). Legacy — prefer `ChatSocketService` + `ChatMessage`. |
| `lib/models/` | Plain immutable models with `fromJson`/`toJson`. Key ones below. |
| `lib/providers/` | Riverpod providers (see below). |

## Key models

- `ServerModel` — an EME Server the user can pick/join. `serverMediaDBUrl` is that server's own
  backend; when set, chat for that server talks to it instead of the default `mediadb`.
- `ServerCategoryModel` — category filter for the server picker.
- `ChatModel` — a row in the Chats list (a 1:1 user chat).
- `ChatMessage` — one message, used for both user DMs and server chat. `messageRenderType`
  (`text | welcome | form | asset | delta | product`) decides the bubble. `deltaOps` (Quill),
  `formFields` (`FormField`/`FormFieldType` in `form_model.dart`), `product`
  (`ProductMessageModel`), `agentContextValues`. See the `eme-sdk-chat-messages` skill.
- `McpServerModel`, `McpChatMessage`, `McpConversationModel` — user-added MCP servers and their chats.
- `UnifiedChatItem` — wraps either a user chat or an MCP conversation for the combined Chats list.
- `EmUser` (auth user), `ProfileModel`, `EmeProfileModel` (people/specialists in "EME World").

## Providers (Riverpod 2, `StateNotifier` style)

- `apiServiceProvider` (`Provider<IApiService>`) and `chatSocketServiceProvider` — **override these in tests**.
- `FutureProvider`s in `api_providers.dart`: `apiServersProvider`, `serverDetailProvider(id)`,
  `apiChatsProvider`, `apiChatMessagesProvider(channelId)`, `apiServerChatMessagesProvider(channelId)`,
  `serverGoalsProvider(serverId)`, etc.
- `serverProvider` (`ServerNotifier`/`ServerState`): server list, categories, search, `toggleJoin`.
- `mcpServersProvider`, `mcpConversationsProvider`, `unifiedChatsProvider` (merges user chats + MCP chats).
- `authProvider`, `emeProfileProvider`, `profileProvider`, `notificationProvider`, `deepLinkProvider`.

## How a request is made

Every backend call follows the same pattern (see `ApiService.fetchChats`):

1. Base URL: `_cleanBaseUrl` → `ApiConfig.baseUrl` → `OpenI.instance.settings.mediadb`.
2. Token: `await SharedPref.getEMKey() ?? AuthService.token`.
3. Headers: `Content-Type: application/json`, `X-tokentype: entermedia`, and when a token exists
   `Authorization: Bearer <token>` + `entermediakey: <token>`.
4. Responses may arrive as a JSON **string** — decode if `data is String`.
5. Payloads are wrapped in varying keys (`emeservers`, `chats`, `messages`, `data`, `results`) — parse defensively.

Main EnterMedia endpoints (relative to mediadb):
`services/module/emeserver/{getemeservers,getemeserver,categories,join,leave}.json`,
`services/module/user/{chats,chat,users,connect}.json`, `services/chat/{chat,connect}.json`.

## Chat flows

- **User ↔ user (DM):** `ChatSocketService().connectUser(fromUser:, toUser:)` → channel id →
  `connect(channel:)` → listen to `messageStream` → `sendMessage(...)`. History: `fetchUserChatMessages(channelId)`.
- **User ↔ EME Server:** `connectChat(serverId)` (channeltype `emeteamchat`) → channel id →
  `connect(channel:, baseUrl: server.serverMediaDBUrl)` → history via
  `fetchServerChatMessages(channelId, baseUrl:)`. Server replies can be forms, deltas, assets or products.
- **User ↔ MCP server:** fully client-side via `McpClientService` + `mcpConversationsProvider`.

The socket is a **singleton** — only one channel is active at a time. Screens must filter
`messageStream` by `channel` and cancel their subscription in `dispose`.

## Rules that apply here (from AGENTS.md)

- No mock/fallback/simulated data in `lib/`. Fail transparently.
- Heads-up: much of the existing `ApiService` code catches errors and returns `[]`/`null`. Don't
  copy that pattern into new code — throw (or return an explicit failure result) so the UI can show
  an error. Ask the user before changing the behaviour of existing methods.
- `ApiConfig.simulatedDelay` exists; don't use it to fake data.

## Commands

```bash
cd ../eme-app-sdk
flutter pub get
flutter analyze
flutter test                      # all SDK tests
flutter test test/mcp_test.dart   # one file
```

Related skills: `eme-sdk-add-api-endpoint`, `eme-sdk-chat-messages`. For the UI side, see the
`eme-app-overview` skill in `eme-app-profile`.
