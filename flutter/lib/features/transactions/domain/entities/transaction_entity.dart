import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String? accountId;
  final String? cardId;
  final String? categoryId;
  final String? tagId;
  final String? accountName;
  final String? cardName;
  final String? categoryName;
  final String? tagName;
  final String? description;
  final DateTime transactedAt;
  final double value;
  final bool ignore;
  final double percentage;

  /// Shared id for paired rows (e.g. account transfers); null for normal transactions.
  final String? transferGroupId;

  /// FK to wallet_credits when this row is a deferred installment.
  final String? creditId;

  /// [wallet_credits.transactedAt] when the credit group row is embedded in the query.
  final DateTime? creditTransactedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.userId,
    this.accountId,
    this.cardId,
    this.categoryId,
    this.tagId,
    this.accountName,
    this.cardName,
    this.categoryName,
    this.tagName,
    this.description,
    required this.transactedAt,
    required this.value,
    required this.ignore,
    required this.percentage,
    this.transferGroupId,
    this.creditId,
    this.creditTransactedAt,
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
      accountName: _embeddedRelationName(json, 'wallet_accounts'),
      cardName: _embeddedRelationName(json, 'wallet_cards'),
      categoryName: _embeddedRelationName(json, 'wallet_categories'),
      tagName: _embeddedRelationName(json, 'wallet_tags'),
      description: json['description'] as String?,
      transactedAt: DateTime.parse(json['transactedAt'] as String),
      value: asDouble(json['value']),
      ignore: json['ignore'] as bool,
      percentage: asDouble(json['percentage']),
      transferGroupId: json['transferGroupId'] as String?,
      creditId: json['creditId'] as String?,
      creditTransactedAt: _embeddedCreditTransactedAt(json),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'userId': userId,
      'accountId': accountId,
      'cardId': cardId,
      'categoryId': categoryId,
      'tagId': tagId,
      'description': description,
      'transactedAt': transactedAt.toUtc().toIso8601String(),
      'value': value,
      'ignore': ignore,
      'percentage': percentage,
      'transferGroupId': transferGroupId,
      'creditId': creditId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
    if (accountName != null) {
      m['wallet_accounts'] = {'name': accountName};
    }
    if (cardName != null) {
      m['wallet_cards'] = {'name': cardName};
    }
    if (categoryName != null) {
      m['wallet_categories'] = {'name': categoryName};
    }
    if (tagName != null) {
      m['wallet_tags'] = {'name': tagName};
    }
    if (creditTransactedAt != null) {
      m['wallet_credits'] = {
        'transactedAt': creditTransactedAt!.toUtc().toIso8601String(),
      };
    }
    return m;
  }

  /// Reads `name` from a PostgREST embedded row, e.g. `wallet_accounts: { name: "…" }`.
  static String? _embeddedRelationName(Map<String, dynamic> json, String key) {
    final rel = json[key];
    if (rel == null) return null;
    if (rel is Map<String, dynamic>) return rel['name'] as String?;
    if (rel is List && rel.isNotEmpty && rel.first is Map<String, dynamic>) {
      return (rel.first as Map<String, dynamic>)['name'] as String?;
    }
    return null;
  }

  static DateTime? _embeddedCreditTransactedAt(Map<String, dynamic> json) {
    final rel = json['wallet_credits'];
    if (rel == null) return null;
    Map<String, dynamic>? m;
    if (rel is Map<String, dynamic>) {
      m = rel;
    } else if (rel is List &&
        rel.isNotEmpty &&
        rel.first is Map<String, dynamic>) {
      m = rel.first as Map<String, dynamic>;
    }
    final ts = m?['transactedAt'];
    if (ts == null) return null;
    return DateTime.parse(ts as String);
  }

  /// True when this row is part of an account/card transfer (paired legs share [transferGroupId]).
  bool get isAccountTransferLeg =>
      transferGroupId != null && transferGroupId!.isNotEmpty;

  /// Same deferred purchase as sibling installments (shared [creditId]).
  String? get creditLedgerGroupingKey =>
      creditId != null && creditId!.isNotEmpty ? creditId : null;

  @override
  List<Object?> get props => [
    id,
    userId,
    accountId,
    cardId,
    categoryId,
    tagId,
    accountName,
    cardName,
    categoryName,
    tagName,
    description,
    transactedAt,
    value,
    ignore,
    percentage,
    transferGroupId,
    creditId,
    creditTransactedAt,
    createdAt,
    updatedAt,
  ];
}
