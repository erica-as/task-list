import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorHex TEXT NOT NULL
      )
    ''');

    await _createDefaultCategories(db);

    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textType,
        priority $textType,
        completed $intType,
        createdAt $textType,

        -- MANTIDO: Campo de Categoria
        categoryId $textType, 

        -- NOVO: Campos da Câmera
        photoPath TEXT,

        -- NOVO: Campos dos Sensores
        completedAt TEXT,
        completedBy TEXT,

        -- NOVO: Campos do GPS
        latitude REAL,
        longitude REAL,
        locationName TEXT,

        -- MANTIDO: Chave Estrangeira
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    print('✅ Banco migrado de v$oldVersion para v$newVersion');
  }

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final maps = await db.query('categories');
    if (maps.isEmpty) return [];
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<Task?> read(int id) async {
    final db = await instance.database;
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
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();

    return allTasks.where((task) {
      if (!task.hasLocation) return false;

      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distanceInMeters = ((latDiff * 111000) + (lonDiff * 111000)) / 2;

      return distanceInMeters <= radiusInMeters;
    }).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
