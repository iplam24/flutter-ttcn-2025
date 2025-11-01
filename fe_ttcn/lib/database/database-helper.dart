import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../model/todo_class.dart';

class DatabaseHelper {
  // khai báo tên cơ sở dữ liệu
  static const _dbName = 'todolistapp_db.db';

  // có thể khai báo thêm phiên bản cho cơ sở dữ liệu (dùng để nâng cấp sau này)
  static const _dbVersion = 1;

  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // khởi tạo database
  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  // tàm tạo bảng + dữ liệu mẫu
  Future<void> _onCreate(Database db, int version) async {
    // tạo bảng ToDo
    await db.execute('''
      CREATE TABLE ToDo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // thêm dữ liệu mẫu
    await db.insert('ToDo', {
      'title': 'Học lập trình Flutter',
      'description': 'Xem video và đọc giáo trình',
      'is_completed': 0,
      'due_date': '2025-08-26',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': null,
    });

    await db.insert('ToDo', {
      'title': 'Học ngôn ngữ lập trình Dart',
      'description': 'Đọc giáo trình',
      'is_completed': 0,
      'due_date': '2025-08-15',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': null,
    });

    await db.insert('ToDo', {
      'title': 'Làm bài tập thiết kế giao diện Flutter',
      'description': 'Tự tổng hợp kiến thức và xem tài liệu trên google',
      'is_completed': 0,
      'due_date': '2025-09-05',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': null,
    });
  }

  // hàm lấy về danh sách các todo list
  Future<List<ToDo>> getTodos() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ToDo',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return ToDo.fromMap(maps[i]);
    });
  }

  // hàm thêm mới một todo list vào bảng ToDo trong CSDL
  Future<int> insertTodo(ToDo todo) async {
    Database db = await database;
    return await db.insert(
      'ToDo',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // hàm cập nhật thông tin của một todo list trong bảng ToDo
  Future<int> updateTodo(ToDo todo) async {
    Database db = await database;
    return await db.update(
      'ToDo',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // hàm xoá một todo list trong bảng ToDo
  Future<int> deleteTodo(int id) async {
    Database db = await database;
    return await db.delete('ToDo', where: 'id = ?', whereArgs: [id]);
  }
}
