class FormFieldOption {
  final dynamic value;
  final String label;

  FormFieldOption({required this.value, required this.label});
  factory FormFieldOption.fromJson(Map<String, dynamic> json) {
    return FormFieldOption(
      value: json['value'],
      label: (json['label'] ?? json['name'] ?? json['value'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'value': value, 'label': label};
  }
}

enum FormFieldType {
  text,
  number,
  boolean,
  select,
  radio,
  checkbox,
  hidden;

  factory FormFieldType.fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return FormFieldType.text;
    }
    final clean = name.toLowerCase().trim();
    return FormFieldType.values.firstWhere(
      (element) => element.name.toLowerCase() == clean,
      orElse: () => FormFieldType.text,
    );
  }
}

class FormField {
  final String name;
  final FormFieldType type;
  final String label;
  final dynamic value;
  final List<FormFieldOption> options;
  final bool? readOnly;

  FormField({
    required this.name,
    required this.type,
    required this.label,
    this.value,
    this.options = const [],
    this.readOnly = false,
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    final rawReadOnly = json['readOnly'] ?? json['readonly'];
    final rawOptions = json['options'] ?? [];
    List<FormFieldOption> options = [];
    if (rawOptions is List) {
      for (var item in rawOptions) {
        if (item is Map) {
          options.add(
            FormFieldOption.fromJson(Map<String, dynamic>.from(item)),
          );
        } else if (item != null) {
          options.add(FormFieldOption(value: item, label: item.toString()));
        }
      }
    }
    return FormField(
      name: (json['name'] ?? '').toString(),
      type: FormFieldType.fromName(json['type']),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      value: json['value'],
      options: options,
      readOnly: rawReadOnly == true || rawReadOnly == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'label': label,
      'value': value,
      'options': options.map((e) => e.toJson()).toList(),
      'readOnly': readOnly,
    };
  }

  FormField copyWith({
    String? name,
    FormFieldType? type,
    String? label,
    dynamic value,
    List<FormFieldOption>? options,
    bool? readOnly,
  }) {
    return FormField(
      name: name ?? this.name,
      type: type ?? this.type,
      label: label ?? this.label,
      value: value ?? this.value,
      options: options ?? this.options,
      readOnly: readOnly ?? this.readOnly,
    );
  }
}
