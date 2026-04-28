import 'package:equatable/equatable.dart';

class AccountEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Sum of all transaction values (non-deleted); from [wallet_accounts_with_balance].
  final double balance;
  /// Sum of value × (percentage / 100) per transaction.
  final double balanceWeighted;
  /// Sum of value for transactions with ignore = false.
  final double balanceCounted;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.balance = 0,
    this.balanceWeighted = 0,
    this.balanceCounted = 0,
  });

  factory AccountEntity.fromJson(Map<String, dynamic> json) => AccountEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
    balanceWeighted: (json['balanceWeighted'] as num?)?.toDouble() ?? 0,
    balanceCounted: (json['balanceCounted'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props =>
      [id, userId, name, description, createdAt, updatedAt, balance, balanceWeighted, balanceCounted];
}
