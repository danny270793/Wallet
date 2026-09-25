import 'package:equatable/equatable.dart';

/// Expected recurring income (positive [value]) or outcome (negative [value]).
class RecurringMovementEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final double value;
  final String? categoryId;
  final String? tagId;

  /// From PostgREST embed `wallet_categories(name)` when selected.
  final String? categoryName;

  /// From PostgREST embed `wallet_tags(name)` when selected.
  final String? tagName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringMovementEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.value,
    this.categoryId,
    this.tagId,
    this.categoryName,
    this.tagName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecurringMovementEntity.fromJson(Map<String, dynamic> json) =>
      RecurringMovementEntity(
        id: json['id'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        value: (json['value'] as num).toDouble(),
        categoryId: json['categoryId'] as String?,
        tagId: json['tagId'] as String?,
        categoryName: _embeddedRelationName(json, 'wallet_categories'),
        tagName: _embeddedRelationName(json, 'wallet_tags'),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'value': value,
      'categoryId': categoryId,
      'tagId': tagId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
    if (categoryName != null) {
      m['wallet_categories'] = {'name': categoryName};
    }
    if (tagName != null) {
      m['wallet_tags'] = {'name': tagName};
    }
    return m;
  }

  static String? _embeddedRelationName(Map<String, dynamic> json, String key) {
    final rel = json[key];
    if (rel == null) return null;
    if (rel is Map<String, dynamic>) return rel['name'] as String?;
    if (rel is List && rel.isNotEmpty && rel.first is Map<String, dynamic>) {
      return (rel.first as Map<String, dynamic>)['name'] as String?;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    description,
    value,
    categoryId,
    tagId,
    categoryName,
    tagName,
    createdAt,
    updatedAt,
  ];
}
