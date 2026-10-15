import 'package:equatable/equatable.dart';

import 'loan_entity.dart';

/// Extra payment straight to a loan's principal, outside the monthly installments.
class LoanCapitalPaymentEntity extends Equatable {
  final String id;
  final String userId;
  final String loanId;
  final double value;

  /// Day it was paid (date only, local).
  final DateTime paidAt;
  final DateTime createdAt;

  const LoanCapitalPaymentEntity({
    required this.id,
    required this.userId,
    required this.loanId,
    required this.value,
    required this.paidAt,
    required this.createdAt,
  });

  factory LoanCapitalPaymentEntity.fromJson(Map<String, dynamic> json) =>
      LoanCapitalPaymentEntity(
        id: json['id'] as String,
        userId: json['userId'] as String,
        loanId: json['loanId'] as String,
        value: (json['value'] as num).toDouble(),
        paidAt: parseLoanDate(json['paidAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'loanId': loanId,
    'value': value,
    'paidAt': formatLoanDate(paidAt),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [id, userId, loanId, value, paidAt, createdAt];
}
