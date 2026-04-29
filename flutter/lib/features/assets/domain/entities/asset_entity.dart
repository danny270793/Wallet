import 'package:equatable/equatable.dart';

class AssetEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String provider;
  final double value;
  final DateTime boughtAt;
  final DateTime? endedAt;
  final double? soldValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssetEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.provider,
    required this.value,
    required this.boughtAt,
    this.endedAt,
    this.soldValue,
    required this.createdAt,
    required this.updatedAt,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.parse(v as String);
  }

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.parse(v as String);
  }

  factory AssetEntity.fromJson(Map<String, dynamic> json) => AssetEntity(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    provider: json['provider'] as String? ?? '',
    value: _toDouble(json['value']),
    boughtAt: DateTime.parse(json['boughtAt'] as String),
    endedAt: json['endedAt'] == null
        ? null
        : DateTime.parse(json['endedAt'] as String),
    soldValue: _toDoubleNullable(json['soldValue']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    provider,
    value,
    boughtAt,
    endedAt,
    soldValue,
    createdAt,
    updatedAt,
  ];
}
