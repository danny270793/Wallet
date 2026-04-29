import 'package:equatable/equatable.dart';

class CardEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Sum of transaction `value` amounts (full row amounts, not value×percentage÷100).
  /// From [wallet_cards_with_balance].
  final double balance;

  const CardEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.balance = 0,
  });

  factory CardEntity.fromJson(Map<String, dynamic> json) => CardEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props =>
      [id, userId, name, description, createdAt, updatedAt, balance];
}
