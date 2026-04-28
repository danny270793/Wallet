import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';

final getIt = GetIt.instance;

void setupDi() {
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt()),
  );
  getIt.registerFactory<SignInUsecase>(() => SignInUsecase(getIt()));
  getIt.registerFactory<LoginBloc>(() => LoginBloc(signIn: getIt()));
}
