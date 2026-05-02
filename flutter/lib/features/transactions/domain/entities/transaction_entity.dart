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
  /// Groups related credit installments (e.g. deferred card purchase split). Legacy installs only.
  final String? creditGroupId;
  /// FK to wallet_credits; preferred grouping for deferred installments (new installs).
  final String? creditId;
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
    this.creditGroupId,
    this.creditId,
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
      creditGroupId: json['creditGroupId'] as String?,
      creditId: json['creditId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
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

  /// True when this row is part of an account/card transfer (paired legs share [transferGroupId]).
  bool get isAccountTransferLeg =>
      transferGroupId != null && transferGroupId!.isNotEmpty;

  /// Same deferred-credit purchase; [creditId] preferred, else legacy [creditGroupId].
  String? get creditLedgerGroupingKey {
    if (creditId != null && creditId!.isNotEmpty) return creditId;
    if (creditGroupId != null && creditGroupId!.isNotEmpty) return creditGroupId;
    return null;
  }

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
    creditGroupId,
    creditId,
    createdAt,
    updatedAt,
  ];
}
