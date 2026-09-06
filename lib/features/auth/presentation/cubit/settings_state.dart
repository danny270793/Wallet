import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsSignedOut extends SettingsState {
  const SettingsSignedOut();
}

class SettingsFailure extends SettingsState {
  const SettingsFailure();
}
