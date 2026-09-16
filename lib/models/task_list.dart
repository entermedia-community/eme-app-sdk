import 'em_data.dart';

class ToDo {
  late String id;
  String? name;
  late Map<String, dynamic> properties;
  List<EmData>? _tasks;

  ToDo.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    name = json["name"];
    properties = json;
  }

  Map<String, dynamic> toJson() {
    properties[id] = id;
    return properties;
  }

  List<EmData>? get tasks {
    if (_tasks == null) {
      var taskjson = properties["tasks"];
      if (taskjson != null) {
        _tasks = taskjson.map<EmData>((json) => EmData.fromJson(json)).toList();
      }
    }
    return _tasks;
  }
}
