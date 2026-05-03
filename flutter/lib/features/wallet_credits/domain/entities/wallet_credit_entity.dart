import 'package:equatable/equatable.dart';

class WalletCreditEntity extends Equatable {
  final String id;
  final String userId;
  final DateTime transactedAt;
  final int graceMonths;
  final int termMonths;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const WalletCreditEntity({
    required this.id,
    required this.userId,
    required this.transactedAt,
    required this.graceMonths,
    required this.termMonths,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory WalletCreditEntity.fromJson(Map<String, dynamic> json) {
    final gm = json['graceMonths'];
    final tm = json['termMonths'];
    return WalletCreditEntity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      transactedAt: DateTime.parse(json['transactedAt'] as String),
      graceMonths: gm is int ? gm : (gm as num).toInt(),
      termMonths: tm is int ? tm : (tm as num).toInt(),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'transactedAt': transactedAt.toUtc().toIso8601String(),
    'graceMonths': graceMonths,
    'termMonths': termMonths,
    'description': description,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props =>
      [id, userId, transactedAt, graceMonths, termMonths, description, createdAt, updatedAt, deletedAt];
}
