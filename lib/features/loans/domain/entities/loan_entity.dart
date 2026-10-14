import 'package:equatable/equatable.dart';

class LoanEntity extends Equatable {
  final String id;
  final String userId;

  /// Account the loan belongs to (where installments are paid from).
  final String accountId;
  final String name;

  /// Amount borrowed.
  final double value;

  /// Nominal annual interest rate as a percentage (16.5 = 16.5%); null when unknown.
  final double? nominalInterestRate;

  /// Number of monthly installments.
  final int termMonths;

  /// Day of month (1–30) installments are due.
  final int paymentDay;

  /// Due date of the first installment (date only, local).
  final DateTime firstPaymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoanEntity({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.name,
    required this.value,
    this.nominalInterestRate,
    required this.termMonths,
    required this.paymentDay,
    required this.firstPaymentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoanEntity.fromJson(Map<String, dynamic> json) => LoanEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    accountId: json['accountId'] as String,
    name: json['name'] as String,
    value: (json['value'] as num).toDouble(),
    nominalInterestRate: (json['nominalInterestRate'] as num?)?.toDouble(),
    termMonths: (json['termMonths'] as num).toInt(),
    paymentDay: (json['paymentDay'] as num).toInt(),
    firstPaymentDate: parseLoanDate(json['firstPaymentDate'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'accountId': accountId,
    'name': name,
    'value': value,
    'nominalInterestRate': nominalInterestRate,
    'termMonths': termMonths,
    'paymentDay': paymentDay,
    'firstPaymentDate': formatLoanDate(firstPaymentDate),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    userId,
    accountId,
    name,
    value,
    nominalInterestRate,
    termMonths,
    paymentDay,
    firstPaymentDate,
    createdAt,
    updatedAt,
  ];
}

/// Postgres `date` (`yyyy-MM-dd`); kept as a local calendar date.
DateTime parseLoanDate(String raw) {
  final d = DateTime.parse(raw);
  return DateTime(d.year, d.month, d.day);
}

String formatLoanDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
