class ToDo {
  // khai báo các thuộc tính map với cơ sở dữ liệu
  int? id;
  String title;
  String? description;
  int isCompleted; // 0: chưa hoàn thành, 1: đã hoàn thành
  String? dueDate;
  String createdAt;
  String? updatedAt;

  // ham khởi tạo
  ToDo({
    this.id,
    required this.title,
    this.description,
    this.isCompleted = 0,
    this.dueDate,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert Map (SQLite) -> Todo object
  factory ToDo.fromMap(Map<String, dynamic> map) {
    return ToDo(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      isCompleted: map['is_completed'],
      dueDate: map['due_date'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  // Convert Todo object -> Map (SQLite)
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
}
