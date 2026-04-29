import 'package:equatable/equatable.dart';
import '../../domain/entities/asset_entity.dart';

sealed class AssetsState extends Equatable {
  const AssetsState();
}

class AssetsInitial extends AssetsState {
  const AssetsInitial();
  @override
  List<Object?> get props => [];
}

class AssetsLoading extends AssetsState {
  const AssetsLoading();
  @override
  List<Object?> get props => [];
}

class AssetsLoaded extends AssetsState {
  final List<AssetEntity> assets;
  const AssetsLoaded(this.assets);
  @override
  List<Object?> get props => [assets];
}

class AssetsError extends AssetsState {
  final String? message;
  const AssetsError({this.message});
  @override
  List<Object?> get props => [message];
}
