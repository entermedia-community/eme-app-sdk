import 'dart:convert';

class EmUser {
  late Map <String, dynamic> properties;
  late String entermediakey;
  String? firstname;
  String? lastname;
  String? email;
  String? firebasepassword;
  late String userid;
  String get id => userid;
  String? screenname;

  EmUser(this.userid, this.email,this.properties);

  EmUser.fromJson(Map<String, dynamic> json){
    userid = json["id"];
    email = json["email"];
    entermediakey = json["entermediakey"];
    screenname = json["screenname"];
    properties = json;
  }

  String toJson() {
    return jsonEncode(properties);
  }
}

