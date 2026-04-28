import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String? accountId;
  final String? cardId;
  final String? categoryId;
  final String? tagId;
  final String? description;
  final DateTime transactedAt;
  final double value;
  final bool ignore;
  final double percentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.userId,
    this.accountId,
    this.cardId,
    this.categoryId,
    this.tagId,
    this.description,
    required this.transactedAt,
    required this.value,
    required this.ignore,
    required this.percentage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionEntity.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => (v as num).toDouble();

    return TransactionEntity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      accountId: json['accountId'] as String?,
      cardId: json['cardId'] as String?,
      categoryId: json['categoryId'] as String?,
      tagId: json['tagId'] as String?,
      description: json['description'] as String?,
      transactedAt: DateTime.parse(json['transactedAt'] as String),
      value: asDouble(json['value']),
      ignore: json['ignore'] as bool,
      percentage: asDouble(json['percentage']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    accountId,
    cardId,
    categoryId,
    tagId,
    description,
    transactedAt,
    value,
    ignore,
    percentage,
    createdAt,
    updatedAt,
  ];
}
