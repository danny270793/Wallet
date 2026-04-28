import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SignOutUsecase _signOut;

  SettingsCubit({required SignOutUsecase signOut})
      : _signOut = signOut,
        super(const SettingsInitial());

  Future<void> signOut() async {
    emit(const SettingsLoading());
    try {
      await _signOut();
      emit(const SettingsSignedOut());
    } catch (_) {
      emit(const SettingsFailure());
    }
  }
}
