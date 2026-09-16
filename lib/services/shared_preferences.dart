import 'dart:convert';

import '../models/em_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPref {
  static Future<void> saveEMKey(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('entermediakey', key);
  }

  static Future<String?> getEMKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    String? stringValue = prefs.getString('entermediakey');
    return stringValue;
  }

  static Future<void> saveEmUser(EmUser emUser) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('emUser', emUser.toJson());
  }

  static Future<EmUser?> getEmUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? stringValue = prefs.getString('emUser');
    if (stringValue == null) {
      return null;
    }
    return EmUser.fromJson(jsonDecode(stringValue));
  }

  static Future<void> saveWorkspaceKey(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('workspacekey', key);
  }

  static Future<String?> getWorkspaceKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    String? stringValue = prefs.getString('workspacekey');
    return stringValue;
  }

  Future<void> saveRecentWorkspace(int colId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('recent', colId);
  }

  Future<void> clearRecentWorkspace() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove("recent");
  }

  Future<int?> getRecentWorkspace() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return index of workspace
    int? intValue = prefs.getInt('recent');
    return intValue;
  }

  Future<void> setRecentEntity(String entity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('recentEntity', entity);
  }

  Future<String?> getRecentEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Return String
    String? stringValue = prefs.getString('recentEntity');
    return stringValue;
  }

  Future<void> clearRecentEntity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove("recentEntity");
  }

  //todo; EX:Handle null int intValue= await prefs.getInt('intValue') ?? 0;
  //todo; EX: Check value SharedPreferences prefs = await SharedPreferences.getInstance();
  //todo; bool CheckValue = prefs.containsKey('value');
  //todo; containsKey will return true if persistent storage contains the given key and false if not.

  static Future<void> resetValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //Remove entermediakey
    prefs.remove("entermediakey");
    //Remove workspacekey
    prefs.remove("workspacekey");
    //Remove most recent workspace ID
    prefs.remove("recent");
    // remove emUser
    prefs.remove("emUser");
  }
}
