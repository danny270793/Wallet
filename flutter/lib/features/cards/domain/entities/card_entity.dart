import 'package:equatable/equatable.dart';

class CardEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CardEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardEntity.fromJson(Map<String, dynamic> json) => CardEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  List<Object?> get props => [id, userId, name, description, createdAt, updatedAt];
}
