# Agent Guidelines & Rules

## 1. No Unrequested Mock or Fallback Data (Strict Rule)

- **Do NOT introduce mock, simulated, or fallback data** in production code (`lib/`) unless explicitly and unambiguously instructed by the user.
- **Fail Transparently**: When an external API, remote service, network endpoint, or Model Context Protocol (MCP) server is offline, unreachable, or returns an error:
  - Return explicit error states, exceptions, or failure results (e.g., `isSuccess: false` with accurate error messages).
  - Do **not** silently catch errors and return fake/simulated "success" payloads.
  - Do **not** inject synthetic fallback tools, sample items, or placeholder records when discovery or fetch operations return empty or fail.
- **No Embedded Simulation Engines**: Never build internal `switch` statements or mock data generators inside production services or clients (e.g., simulating weather, media searches, or database queries) to mask missing backend integrations.

## 2. Proper Separation of Test Mocks

- Mock data and fake responses belong **strictly within test suites** (`test/`) using proper mocking libraries (e.g., `mocktail`, `mockito`, or HTTP mock adapters).
- Never pollute production service classes with mock data branches for the sake of tests. Use dependency injection and mock interfaces instead.

## 3. Transparency & Requirement Clarification

- If a backend endpoint, data schema, or remote capability is not yet implemented or unavailable:
  - Implement real error handling for the unavailable state.
  - Ask the user for guidance or clarification if uncertain, rather than inventing mock implementations.

## 4. Authentication: every EME app uses the SDK (Strict Rule)

All Flutter apps under `eme-app-*` (profile, chatbot, datamanager, ...) sign in through `eme_app_sdk`. Never write a per-app login, token store or key handling, and never use `Authorization: Bearer` for user sessions. Web reference implementations: `eme-server-communities/plugins/community/html/default/authentication/authentication.js` and `.../components/javascript/emedia/ajax/signedheaders.js`.

**Flow**
1. `authProvider.notifier.sendUserCode(email:)` posts `services/authentication/sendusercode.json` and emails a 6 digit code (status `ok` / `nouser` / error).
2. `authProvider.notifier.loginWithCode(email:, code:)` posts `services/authentication/token.json` with `grant_type=otp`, `email`, `code`, `publickey` (base64url SPKI of a new device key), `label`. `publickey` is **required**: without it the server answers 400 "email, code and publickey are required". Browsers need a secure context (https or localhost) for the key.
3. The server returns `access_token`, `key_id`, `user`. The SDK stores the device key (`flutter_secure_storage` on native; non-extractable WebCrypto key in IndexedDB `emebrowserkey` / `keys` / `current` on web, the same record `authentication.js` uses), plus the user and token in `SharedPref`.
4. A code is single use. If the UI shows "wrong code" after a first submit, check the server log for an earlier `token.json` 200: the login succeeded and a client side step failed.

**Every request is signed**
- Headers: `X-tokentype: signature` and `X-token: {"username","key_id","timestamp","nonce","signature"}`. `signature` signs `username\nkey_id\ntimestamp\nnonce` with the device key. It is reused for 24h, then re-signed with a new nonce.
- Get them with `await SignedTokenProvider.instance.headers()` (empty map = signed out, the server answers 401). `SignedTokenProvider.instance.clear()` forgets the cached signature (do this on a 401, then retry once).
- `Image.network` and other sync callers cannot await: expose the headers through a Riverpod `FutureProvider` and wait for it.

**App setup (`main()`)**
- `await DioUtil.init();` then `await OpenI().initialize({'mediadb': '<server>/site/mediadb', 'siteroot': '<server>', 'catalogid': 'site/catalog'});`. When the server address changes at runtime call `OpenI.instance?.updateSettings(...)`.
- Read auth state from `authProvider` (`AuthState`: `status`, `user`, `isAuthenticated`, `isCodeSent`); sign out with `authProvider.notifier.logout()`, which revokes the key and clears all stored credentials.
- Firebase/push is optional. Failures there (secure storage, Firebase not initialised) must never fail a login: keep them in try/catch and never replace a real error with a generic message.

**Riverpod**: all EME apps and the SDK use `flutter_riverpod ^3.5.0`. `StateNotifier`/`StateNotifierProvider`/`StateProvider` come from `package:flutter_riverpod/legacy.dart`; use `.value` (not `valueOrNull`).

**Not supported**: app passwords (`emeapp.` prefix), per-app OTP code, hand-made Ed25519 key code.
