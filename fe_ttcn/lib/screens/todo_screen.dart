// lib/screens/todo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../model/todo_class.dart';
import 'package:intl/intl.dart';

class ToDoScreen extends StatefulWidget {
  const ToDoScreen({super.key});
  @override
  State<ToDoScreen> createState() => _ToDoScreenState();
}

class _ToDoScreenState extends State<ToDoScreen> {
  List<ToDo> _todos = [];
  final _titleController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final todos = await _dbHelper.getTodos();
    setState(() => _todos = todos);
  }

  Future<void> _addTodo() async {
    if (_titleController.text.trim().isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final todo = ToDo(
      title: _titleController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _dbHelper.insertTodo(todo);
    _titleController.clear();
    _loadTodos();
  }

  Future<void> _toggleComplete(ToDo todo) async {
    final updated = todo.copyWith(
      isCompleted: todo.isCompleted == 1 ? 0 : 1,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.updateTodo(updated);
    _loadTodos();
  }

  Future<void> _deleteTodo(int id) async {
    await _dbHelper.deleteTodo(id);
    _loadTodos();
  }

  Future<void> _showEditDialog(ToDo todo) async {
    final titleController = TextEditingController(text: todo.title);
    final descriptionController = TextEditingController(text: todo.description);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sửa công việc'),
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
                  decoration: const InputDecoration(labelText: 'Mô tả (Tùy chọn)'),
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

                final updated = todo.copyWith(
                  title: titleController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                  updatedAt: DateTime.now().toIso8601String(),
                );
                await _dbHelper.updateTodo(updated);
                Navigator.pop(context);
                _loadTodos();
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Việc cần làm'),
        backgroundColor: Colors.teal, // Màu Teal
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Thêm việc mới...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'addTodo',
                  onPressed: _addTodo,
                  backgroundColor: Colors.teal,
                  mini: true,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: _todos.isEmpty
                ? const Center(
              child: Text(
                'Chưa có việc nào\nThêm việc để bắt đầu!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _todos.length,
              itemBuilder: (ctx, i) {
                final todo = _todos[i];
                final isCompleted = todo.isCompleted == 1;

                return Dismissible(
                  key: ValueKey(todo.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => _deleteTodo(todo.id!),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_forever, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2, // Tăng nhẹ elevation
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Checkbox(
                        value: isCompleted,
                        activeColor: Colors.teal,
                        onChanged: (_) => _toggleComplete(todo),
                      ),
                      title: Text(
                        todo.title,
                        style: TextStyle(
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey.shade600 : Colors.black87,
                          fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                      subtitle: todo.description != null && todo.description!.isNotEmpty
                          ? Text(
                        todo.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, fontStyle: isCompleted ? FontStyle.italic : null
                        ),
                      )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                        onPressed: () => _showEditDialog(todo),
                      ),
                      onTap: () => _showEditDialog(todo), // Mở dialog khi chạm vào
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}