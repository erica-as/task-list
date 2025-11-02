import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/task.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorHex TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    await _createDefaultCategories(db);
  }

  Future<void> _createDefaultCategories(Database db) async {
    final uuid = Uuid();
    final defaultCategories = [
      Category(id: 'default', name: 'Geral', colorHex: '#9E9E9E'), // Cinza
      Category(id: uuid.v4(), name: 'Trabalho', colorHex: '#2196F3'), // Azul
      Category(id: uuid.v4(), name: 'Pessoal', colorHex: '#4CAF50'), // Verde
      Category(id: uuid.v4(), name: 'Estudos', colorHex: '#FFC107'), // Amarelo
    ];

    final batch = db.batch();
    for (final category in defaultCategories) {
      batch.insert('categories', category.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final maps = await db.query('categories');
    if (maps.isEmpty) return [];
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await database;

    final maps = await db.rawQuery('''
      SELECT 
        t.*, 
        c.name as categoryName, 
        c.colorHex as categoryColorHex
      FROM tasks t
      LEFT JOIN categories c ON t.categoryId = c.id
      ORDER BY t.createdAt DESC
    ''');

    if (maps.isEmpty) return [];

    return maps.map((map) => Task.fromMapWithCategory(map)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
