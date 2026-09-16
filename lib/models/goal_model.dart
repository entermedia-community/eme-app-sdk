class GoalTaskItemModel {
  final String id;
  final String title;
  final String? assignedRole;
  final String addedBy;
  final String addedAgo;
  final bool isResolved;

  const GoalTaskItemModel({
    required this.id,
    required this.title,
    this.assignedRole,
    required this.addedBy,
    required this.addedAgo,
    this.isResolved = false,
  });

  factory GoalTaskItemModel.fromJson(Map<String, dynamic> json) {
    return GoalTaskItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assignedRole: json['assignedRole'] as String?,
      addedBy: json['addedBy'] as String? ?? '',
      addedAgo: json['addedAgo'] as String? ?? '',
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (assignedRole != null) 'assignedRole': assignedRole,
      'addedBy': addedBy,
      'addedAgo': addedAgo,
      'isResolved': isResolved,
    };
  }

  GoalTaskItemModel copyWith({
    String? id,
    String? title,
    String? assignedRole,
    String? addedBy,
    String? addedAgo,
    bool? isResolved,
  }) {
    return GoalTaskItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      assignedRole: assignedRole ?? this.assignedRole,
      addedBy: addedBy ?? this.addedBy,
      addedAgo: addedAgo ?? this.addedAgo,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

class GoalItemModel {
  final String id;
  final String title;
  final String dueDate;
  final String createdAgo;
  final String createdBy;
  final String ticketType;
  final List<GoalTaskItemModel> tasks;
  final bool isResolved;

  const GoalItemModel({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.createdAgo,
    required this.createdBy,
    this.ticketType = 'Chat',
    required this.tasks,
    this.isResolved = false,
  });

  factory GoalItemModel.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? [];
    return GoalItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      createdAgo: json['createdAgo'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      ticketType: json['ticketType'] as String? ?? 'Chat',
      tasks: rawTasks
          .map((t) => GoalTaskItemModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate,
      'createdAgo': createdAgo,
      'createdBy': createdBy,
      'ticketType': ticketType,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'isResolved': isResolved,
    };
  }

  GoalItemModel copyWith({
    String? id,
    String? title,
    String? dueDate,
    String? createdAgo,
    String? createdBy,
    String? ticketType,
    List<GoalTaskItemModel>? tasks,
    bool? isResolved,
  }) {
    return GoalItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      createdAgo: createdAgo ?? this.createdAgo,
      createdBy: createdBy ?? this.createdBy,
      ticketType: ticketType ?? this.ticketType,
      tasks: tasks ?? this.tasks,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
