// lib/model/todo_class.dart
class ToDo {
  final int? id;
  String title;
  String? description;
  int isCompleted;
  String? dueDate;
  final String createdAt;
  String? updatedAt;

  ToDo({
    this.id,
    required this.title,
    this.description,
    this.isCompleted = 0,
    this.dueDate,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'due_date': dueDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static ToDo fromMap(Map<String, dynamic> map) {
    return ToDo(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'],
      isCompleted: map['is_completed'] ?? 0,
      dueDate: map['due_date'],
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
    );
  }

  ToDo copyWith({
    int? id,
    String? title,
    String? description,
    int? isCompleted,
    String? dueDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return ToDo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}