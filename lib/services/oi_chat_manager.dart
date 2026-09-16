import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../models/oi_chat_message.dart';
import '../openinsitute_core.dart';

class OiChatManager {
  String chatBox = "oiChatManagerCache";
  List? fieldProjectChatChangeListeners;

  OpenI get oi {
    return Get.find();
  }

  Future<void> cacheChat(String projectId, List<OIChatMessage> messages) async {
    messages.sort(
      (a, b) => DateTime.parse(
        a.properties["date"],
      ).compareTo(DateTime.parse(b.properties["date"])),
    );
  }

  Future<void> loadChat(String projectId, int page) async {
    List<OIChatMessage> messages = [];
    List<OIChatMessage> result = await getProjectChatMessages(projectId, page);
    if (result.isNotEmpty) {
      messages.addAll(result);
      await cacheChat(projectId, result);
    }
  }

  /// Firebase can call this when it sees that a chat event came in
  /// so we can invalidate our local cache and update our list of chats
  void chatMessageEdited(String inMessageId, String inUserId) async {
    // var box = await getBox("oiChatManagerCache");

    //fieldProjectChatChangeListeners;
  }

  Map getParams(int page, String inProjectId) {
    return {"page": "$page", "hitsperpage": "20", "collectionid": inProjectId};
  }

  Future<List<OIChatMessage>> getProjectChatMessages(
    String inProjectId,
    int page,
  ) async {
    final Map? responded = await oi.postEntermedia(
      '${oi.settings.mediadb}/services/module/librarycollection/viewmessages.json',
      getParams(page, inProjectId),
    );
    List<OIChatMessage> messages = responded!["results"]!
        .map<OIChatMessage>((json) => OIChatMessage.fromJson(json))
        .toList();
    return Future.value(messages);
  }

  Future<void> saveChat(OIChatMessage inMessage, String projectId) async {
    try {
      final Map? responded = await oi.postEntermedia(
        '${oi.settings.mediadb}/services/module/librarycollection/savemessage.json',
        inMessage.properties,
      );
      log("Saved chat message: $responded");
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
