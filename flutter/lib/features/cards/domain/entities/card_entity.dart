import 'package:equatable/equatable.dart';

import 'card_type.dart';

class CardEntity extends Equatable {
  final String id;
  final String userId;
  final String name;

  /// Card network; null only for cards created before types existed.
  final CardType? type;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Day of month (1–30) for the billing statement cut.
  final int cutDay;

  /// Day of month (1–30) for payment due.
  final int payDay;

  /// Nominal annual interest rate as a percentage (16.5 = 16.5%); null when unknown.
  final double? nominalInterestRate;

  /// Sum of transaction `value` for rows on this card with no [creditId]
  /// (deferred installments are excluded; see /credits).
  /// From [wallet_cards_with_balance].
  final double balance;

  const CardEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.type,
    required this.createdAt,
    required this.updatedAt,
    this.cutDay = 24,
    this.payDay = 24,
    this.nominalInterestRate,
    this.balance = 0,
  });

  factory CardEntity.fromJson(Map<String, dynamic> json) => CardEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    type: CardType.fromWire(json['type'] as String?),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    cutDay: (json['cutDay'] as num?)?.toInt() ?? 24,
    payDay: (json['payDay'] as num?)?.toInt() ?? 24,
    nominalInterestRate: (json['nominalInterestRate'] as num?)?.toDouble(),
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'type': type?.wireValue,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'cutDay': cutDay,
    'payDay': payDay,
    'nominalInterestRate': nominalInterestRate,
    'balance': balance,
  };

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    createdAt,
    updatedAt,
    cutDay,
    payDay,
    nominalInterestRate,
    balance,
  ];
}
