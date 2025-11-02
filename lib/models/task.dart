import 'package:uuid/uuid.dart';
import 'category.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final String categoryId;
  final Category? category;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    required this.categoryId,
    this.category,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      completed: map['completed'] == 1,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt']),
      categoryId: map['categoryId'] ?? 'default',
    );
  }

  factory Task.fromMapWithCategory(Map<String, dynamic> map) {
    Category? category;

    if (map['categoryId'] != null && map['categoryName'] != null) {
      category = Category(
        id: map['categoryId'] as String,
        name: map['categoryName'] as String,
        colorHex: map['categoryColorHex'] as String,
      );
    }

    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] ?? '',
      completed: map['completed'] == 1,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt'] as String),
      categoryId: map['categoryId'] as String,
      category: category,
    );
  }

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
    String? categoryId,
    Category? category,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
    );
  }
}
