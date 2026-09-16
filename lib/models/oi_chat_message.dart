class OIChatMessage {
  late Map<String, dynamic> properties;
  late String messageid;
  late Map user;

  OIChatMessage(this.messageid, this.user, this.properties);

  OIChatMessage.fromJson(Map<String, dynamic> json) {
    messageid = json["id"];
    user = json["user"];
    properties = json;
  }
}
