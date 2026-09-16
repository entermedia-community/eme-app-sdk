class EmData {
  late String id;
  late String name;
  late Map<String, dynamic> properties;

  EmData(this.id, this.name, this.properties);

  EmData.fromJson(Map<String, dynamic> json) {
    id = json["id"];

    var langname = json["name"];
    if (langname == null) {
      name = "No Name";
    } else if (langname.runtimeType == String) {
      name = langname;
    } else if (langname["en"] != null) {
      name = langname["en"];
    }
    properties = json;
  }

  Map<String, dynamic> toJson() {
    return properties;
  }
}
