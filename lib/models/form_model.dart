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
  hidden,

  /// A calendar date, sent as `yyyy-MM-dd`.
  date,

  /// A time of day, sent as `HH:mm`.
  time,

  /// A date and time (HTML `datetime-local`), sent as `yyyy-MM-ddTHH:mm`.
  datetime,

  /// Multi-line text.
  textarea;

  /// Other names the server uses for a type.
  static const _aliases = {
    'datetime-local': FormFieldType.datetime,
    'multiline': FormFieldType.textarea,
    'paragraph': FormFieldType.textarea,
  };

  factory FormFieldType.fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return FormFieldType.text;
    }
    final clean = name.toLowerCase().trim();
    final alias = _aliases[clean];
    if (alias != null) return alias;
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

  /// The form can't be submitted while this field is empty.
  final bool required;

  FormField({
    required this.name,
    required this.type,
    required this.label,
    this.value,
    this.options = const [],
    this.readOnly = false,
    this.required = false,
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    final rawReadOnly = json['readOnly'] ?? json['readonly'];
    final rawRequired = json['required'];
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
      required: rawRequired == true || rawRequired == 'true',
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
      if (required) 'required': true,
    };
  }

  FormField copyWith({
    String? name,
    FormFieldType? type,
    String? label,
    dynamic value,
    List<FormFieldOption>? options,
    bool? readOnly,
    bool? required,
  }) {
    return FormField(
      name: name ?? this.name,
      type: type ?? this.type,
      label: label ?? this.label,
      value: value ?? this.value,
      options: options ?? this.options,
      readOnly: readOnly ?? this.readOnly,
      required: required ?? this.required,
    );
  }
}
