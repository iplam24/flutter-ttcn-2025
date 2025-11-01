// lib/screens/todo_list_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database-helper.dart';
import '../model/todo_class.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  late DatabaseHelper _dbHelper;
  Future<List<ToDo>>? _todoListFuture;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    _loadTodos();
  }

  // Tải lại danh sách công việc
  void _loadTodos() {
    setState(() {
      _todoListFuture = _dbHelper.getTodos();
    });
  }

  // Hiển thị dialog để thêm/sửa công việc
  Future<void> _showTodoDialog([ToDo? todo]) async {
    final titleController = TextEditingController(text: todo?.title);
    final descriptionController =
    TextEditingController(text: todo?.description);
    DateTime? selectedDate =
    todo?.dueDate != null ? DateTime.tryParse(todo!.dueDate!) : null;

    final isEditing = todo != null;

    await showDialog(
      context: context,
      builder: (context) {
        // Dùng StatefulBuilder để cập nhật ngày trong dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Sửa công việc' : 'Thêm công việc'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                      autofocus: true,
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate == null
                                ? 'Chưa có hạn chót'
                                : 'Hạn: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                          ),
                        ),
                        TextButton(
                          child: const Text('Chọn ngày'),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                selectedDate = pickedDate;
                              });
                            }
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Huỷ'),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;

                    if (isEditing) {
                      // Cập nhật
                      todo.title = titleController.text;
                      todo.description = descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null;
                      todo.dueDate = selectedDate?.toIso8601String();
                      todo.updatedAt = DateTime.now().toIso8601String();
                      await _dbHelper.updateTodo(todo);
                    } else {
                      // Thêm mới
                      final newTodo = ToDo(
                        title: titleController.text,
                        description: descriptionController.text.isNotEmpty
                            ? descriptionController.text
                            : null,
                        createdAt: DateTime.now().toIso8601String(),
                        dueDate: selectedDate?.toIso8601String(),
                      );
                      await _dbHelper.insertTodo(newTodo);
                    }
                    Navigator.pop(context);
                    _loadTodos();
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Xoá công việc
  Future<void> _deleteTodo(int id) async {
    // Tùy chọn: Hiển thị dialog xác nhận
    await _dbHelper.deleteTodo(id);
    _loadTodos();
  }

  // Đánh dấu hoàn thành
  Future<void> _toggleTodoStatus(ToDo todo) async {
    todo.isCompleted = todo.isCompleted == 1 ? 0 : 1;
    todo.updatedAt = DateTime.now().toIso8601String();
    await _dbHelper.updateTodo(todo);
    _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách To-Do')),
      body: FutureBuilder<List<ToDo>>(
        future: _todoListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có công việc nào.'));
          }

          final todos = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              final isCompleted = todo.isCompleted == 1;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (val) => _toggleTodoStatus(todo),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (todo.description != null &&
                          todo.description!.isNotEmpty)
                        Text(todo.description!),
                      if (todo.dueDate != null)
                        Text(
                          'Hạn: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(todo.dueDate!))}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteTodo(todo.id!),
                  ),
                  onTap: () => _showTodoDialog(todo),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTodoDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}