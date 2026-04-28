import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/cubit/settings_cubit.dart';
import '../../features/accounts/data/datasources/accounts_remote_datasource.dart';
import '../../features/accounts/data/repositories/accounts_repository_impl.dart';
import '../../features/accounts/domain/repositories/accounts_repository.dart';
import '../../features/accounts/domain/usecases/get_accounts_usecase.dart';
import '../../features/accounts/domain/usecases/create_account_usecase.dart';
import '../../features/accounts/domain/usecases/update_account_usecase.dart';
import '../../features/accounts/domain/usecases/delete_account_usecase.dart';
import '../../features/accounts/presentation/cubit/accounts_cubit.dart';

final getIt = GetIt.instance;

void setupDi() {
  // auth
  getIt.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt()),
  );
  getIt.registerFactory<SignInUsecase>(() => SignInUsecase(getIt()));
  getIt.registerFactory<SignOutUsecase>(() => SignOutUsecase(getIt()));
  getIt.registerFactory<LoginBloc>(() => LoginBloc(signIn: getIt()));
  getIt.registerFactory<SettingsCubit>(() => SettingsCubit(signOut: getIt()));

  // accounts
  getIt.registerLazySingleton<AccountsRemoteDatasource>(
    () => AccountsSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<AccountsRepository>(
    () => AccountsRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetAccountsUsecase>(() => GetAccountsUsecase(getIt()));
  getIt.registerFactory<CreateAccountUsecase>(() => CreateAccountUsecase(getIt()));
  getIt.registerFactory<UpdateAccountUsecase>(() => UpdateAccountUsecase(getIt()));
  getIt.registerFactory<DeleteAccountUsecase>(() => DeleteAccountUsecase(getIt()));
  getIt.registerFactory<AccountsCubit>(
    () => AccountsCubit(
      getAccounts: getIt(),
      createAccount: getIt(),
      updateAccount: getIt(),
      deleteAccount: getIt(),
    ),
  );
}
