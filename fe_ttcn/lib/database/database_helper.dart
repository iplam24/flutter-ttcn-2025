// lib/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import '../model/todo_class.dart';
import '../model/schedule_item.dart';

class DatabaseHelper {
  static const _dbName = 'todolistapp_db.db';
  static const _dbVersion = 2;

  static const String TABLE_TODO = 'ToDo';
  static const String TABLE_SCHEDULE = 'schedule';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $TABLE_TODO (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $TABLE_SCHEDULE (
        id INTEGER PRIMARY KEY,
        mssv TEXT NOT NULL,
        maMon TEXT,
        tenMon TEXT,
        nhom INTEGER,
        toNhom INTEGER,
        soTinChi INTEGER,
        lop TEXT,
        thu INTEGER,
        tietBatDau INTEGER,
        soTiet INTEGER,
        phong TEXT,
        giangVien TEXT,
        tuanSo INTEGER,
        date TEXT NOT NULL
      )
    ''');

    // Dữ liệu mẫu
    final now = DateTime.now().toIso8601String();
    await db.insert(TABLE_TODO, {
      'title': 'Học Flutter',
      'description': 'Làm đồ án',
      'is_completed': 0,
      'due_date': '2025-12-31',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE $TABLE_SCHEDULE (
          id INTEGER PRIMARY KEY,
          mssv TEXT NOT NULL,
          maMon TEXT,
          tenMon TEXT,
          nhom INTEGER,
          toNhom INTEGER,
          soTinChi INTEGER,
          lop TEXT,
          thu INTEGER,
          tietBatDau INTEGER,
          soTiet INTEGER,
          phong TEXT,
          giangVien TEXT,
          tuanSo INTEGER,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  // ==================== SCHEDULE METHODS ====================

  Future<void> replaceAllSchedule(List<ScheduleItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(TABLE_SCHEDULE);
      final batch = txn.batch();
      for (var item in items) {
        batch.insert(TABLE_SCHEDULE, item.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<ScheduleItem>> getScheduleByDate(DateTime date) async {
    final db = await database;
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final maps = await db.query(
      TABLE_SCHEDULE,
      where: 'date = ?',
      whereArgs: [ymd],
      orderBy: 'tietBatDau ASC',
    );
    return maps.map((m) => ScheduleItem.fromMap(m)).toList();
  }

  Future<List<ScheduleItem>> getScheduleForWeek(DateTime date) async {
    final db = await database;
    final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
    final sunday = monday.add(const Duration(days: 6));

    final startStr = DateFormat('yyyy-MM-dd').format(monday);
    final endStr = DateFormat('yyyy-MM-dd').format(sunday.add(const Duration(days: 1)));

    final maps = await db.query(
      TABLE_SCHEDULE,
      where: 'date >= ? AND date < ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date ASC, tietBatDau ASC',
    );
    return maps.map((m) => ScheduleItem.fromMap(m)).toList();
  }

  Future<void> clearSchedule() async {
    final db = await database;
    await db.delete(TABLE_SCHEDULE);
  }

  Future<List<ScheduleItem>> getAllSchedule() async {
    final db = await database;
    final maps = await db.query(TABLE_SCHEDULE, orderBy: 'date ASC');
    return maps.map((m) => ScheduleItem.fromMap(m)).toList();
  }

  // ==================== TODO METHODS ====================

  Future<List<ToDo>> getTodos() async {
    final db = await database;
    // Sắp xếp theo chưa hoàn thành (0) trước, sau đó theo ngày tạo mới nhất
    final maps = await db.query(
        TABLE_TODO,
        orderBy: 'is_completed ASC, created_at DESC'
    );
    return maps.map((m) => ToDo.fromMap(m)).toList();
  }

  Future<int> insertTodo(ToDo todo) async {
    final db = await database;
    return await db.insert(TABLE_TODO, todo.toMap());
  }

  Future<int> updateTodo(ToDo todo) async {
    final db = await database;
    return await db.update(
      TABLE_TODO,
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      TABLE_TODO,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ScheduleItem>> getScheduleForDay(DateTime date) async {
    final db = await database;
    // Format date thành 'yyyy-MM-dd' để query
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final maps = await db.query(
      TABLE_SCHEDULE,
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: 'tietBatDau ASC', // Sắp xếp theo tiết bắt đầu
    );
    return maps.map((m) => ScheduleItem.fromMap(m)).toList();
  }
}