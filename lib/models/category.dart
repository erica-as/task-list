import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String colorHex;

  Category({required this.id, required this.name, required this.colorHex});

  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorHex': colorHex};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String,
    );
  }
}
