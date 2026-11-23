# Lead capture API (embeddable chatbot)

## GET `services/module/librarycollection/vendor.json?urlname=<urlname>` (implemented)

Public, no login. A vendor is a `librarycollection` with `collectiontype=8`, matched on
`urlname` exactly (case-sensitive). Its menu is the `automationscenario` rows listed in
`librarycollection.vendorscenario`. Disabled scenarios (`enabled=false`) are left out, and
the rest are sorted by `ordering`. Client: `LeadService.fetchVendor`.

```json
{
  "response": { "status": "ok" },
  "vendor": {
    "id": "AaIJ_oFkvuisFDK6Jo7H", "name": "Vendor 1", "urlname": "VendorOne",
    "menu": [
      { "id": "entity_chat_questions", "name": "Answer Questions",
        "description": "<longcaption>", "icon": "<scenarioicon>", "chatenabled": true }
    ]
  }
}
```

Unknown vendor: HTTP 200 with `{"response": {"status": "error", "error": "vendor not found"}}`.
The template is `eme-server/plugins/mediadb/html/services/module/librarycollection/vendor.json`.

## Lead endpoints

Status: **proposed**. The client (`LeadService` in `lib/services/lead_service.dart`,
used by `eme_chatbot`) is built against this contract. The eme-server side is not
implemented yet.

The paths below are relative to `mediadb` (for example `https://eme.world/site/mediadb`) under
`services/module/lead/`. Bodies are JSON. Errors are a non-2xx status with
`{"error": "<message>"}`. The client shows that message to the visitor.

Visitors are anonymous: `questionnaire.json` and `startlead.json` need no auth.
`startlead.json` returns a session token scoped to that one lead. Later calls send it as
`entermediakey: <token>` and `Authorization: Bearer <token>`. These endpoints are public,
so the server should:

- rate-limit by IP and vendor
- check `Origin` against the vendor's allowed website domains
- reject a token used for any lead other than its own

## GET `questionnaire.json?vendorid=<id>`

```json
{
  "questionnaire": {
    "id": "Q1",
    "vendorid": "acme",
    "vendorname": "Acme",                 // shown in the chat header
    "greeting": "Hi! Welcome to Acme.",   // optional, first bot message
    "consenttext": "Can we contact you by email about your enquiry?",
    "thankyou": "Thanks! We'll be in touch.", // optional
    "questions": [
      {
        "id": "budget",
        "prompt": "What is your budget?",
        "type": "radio",          // text | number | boolean | select | radio | checkbox | hidden
        "required": true,
        "placeholder": "",        // optional, for text/number
        "options": [{ "value": "lt10", "label": "< 10k" }],
        "value": null             // hidden only: sent automatically, never asked
      }
    ]
  }
}
```

Questions are asked in array order, one at a time. Name and email are always collected
first by the app, so don't put them in `questions`.

## POST `startlead.json`

Request: `{"vendorid", "questionnaireid", "name", "email"}`

Creates the lead and its chat channel, and returns:

```json
{ "lead": { "leadid": "L1", "userid": "<anonymous user id>", "token": "<session token>", "channel": "<channel id>" } }
```

All four fields are required. `userid` and `channel` are used to connect to the chat
WebSocket (`ChatConnection?userid=&channel=&entermedia.key=`).

## POST `answer.json` (auth)

Request: `{"leadid", "questionid", "value"}`. `value` is a string, number, boolean or,
for `checkbox`, a list of option values. The app sends this once per answered question,
so a partly finished questionnaire is still recorded. Sending the same `questionid` again
replaces the earlier answer.

Response: any 2xx.

## POST `complete.json` (auth)

Request: `{"leadid", "consent": true}`. Records consent and marks the lead complete.

Response: `{"thankyou": "..."}` (optional; otherwise the app uses
`questionnaire.thankyou`, then its own default text).

## GET `messages.json?leadid=<id>` (auth)

Every message on the lead's channel, in `ChatMessage.fromJson` format, so the visitor
sees admin replies sent while they were away:

```json
{ "messages": [ { "id": "m1", "channel": "ch1", "user": "admin", "message": "Hi Ada!", "messagetype": "message", "date": 1764000000000 } ] }
```

Messages from the visitor's own `userid` are ignored, because the app already has them
locally.

### Email log entries

When an automated or manual email is sent to the lead, post a message on the lead's
channel with `"messagetype": "emaillog"` and a short human-readable `message`, for example
`"We emailed you on 24 Nov about pricing"`. The app shows it as a centred system note
rather than a chat bubble. The same message type works over the WebSocket for live
delivery.
