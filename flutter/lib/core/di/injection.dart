import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../locale/app_locale_controller.dart';
import '../theme/app_theme_controller.dart';
import '../wallet_actions/wallet_actions_datasource.dart';
import '../wallet_actions/wallet_actions_reporter.dart';
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
import '../../features/accounts/domain/usecases/adjust_account_balance_via_transaction_usecase.dart';
import '../../features/accounts/presentation/cubit/accounts_cubit.dart';
import '../../features/cards/data/datasources/cards_remote_datasource.dart';
import '../../features/cards/data/repositories/cards_repository_impl.dart';
import '../../features/cards/domain/repositories/cards_repository.dart';
import '../../features/cards/domain/usecases/get_cards_usecase.dart';
import '../../features/cards/domain/usecases/create_card_usecase.dart';
import '../../features/cards/domain/usecases/update_card_usecase.dart';
import '../../features/cards/domain/usecases/delete_card_usecase.dart';
import '../../features/cards/domain/usecases/adjust_card_balance_via_transaction_usecase.dart';
import '../../features/cards/presentation/cubit/cards_cubit.dart';
import '../../features/categories/data/datasources/categories_remote_datasource.dart';
import '../../features/categories/data/repositories/categories_repository_impl.dart';
import '../../features/categories/domain/repositories/categories_repository.dart';
import '../../features/categories/domain/usecases/get_categories_usecase.dart';
import '../../features/categories/domain/usecases/create_category_usecase.dart';
import '../../features/categories/domain/usecases/update_category_usecase.dart';
import '../../features/categories/domain/usecases/delete_category_usecase.dart';
import '../../features/categories/presentation/cubit/categories_cubit.dart';
import '../../features/tags/data/datasources/tags_remote_datasource.dart';
import '../../features/tags/data/repositories/tags_repository_impl.dart';
import '../../features/tags/domain/repositories/tags_repository.dart';
import '../../features/tags/domain/usecases/get_tags_usecase.dart';
import '../../features/tags/domain/usecases/create_tag_usecase.dart';
import '../../features/tags/domain/usecases/update_tag_usecase.dart';
import '../../features/tags/domain/usecases/delete_tag_usecase.dart';
import '../../features/tags/presentation/cubit/tags_cubit.dart';
import '../../features/assets/data/datasources/assets_remote_datasource.dart';
import '../../features/assets/data/repositories/assets_repository_impl.dart';
import '../../features/assets/domain/repositories/assets_repository.dart';
import '../../features/assets/domain/usecases/create_asset_usecase.dart';
import '../../features/assets/domain/usecases/delete_asset_usecase.dart';
import '../../features/assets/domain/usecases/get_assets_usecase.dart';
import '../../features/assets/domain/usecases/update_asset_usecase.dart';
import '../../features/assets/presentation/cubit/assets_cubit.dart';
import '../../features/transactions/data/datasources/transactions_remote_datasource.dart';
import '../../features/transactions/data/repositories/transactions_repository_impl.dart';
import '../../features/transactions/domain/repositories/transactions_repository.dart';
import '../../features/transactions/domain/usecases/get_transactions_usecase.dart';
import '../../features/transactions/domain/usecases/get_transactions_for_year_usecase.dart';
import '../../features/transactions/domain/usecases/get_transactions_by_credit_group_id_usecase.dart';
import '../../features/transactions/domain/usecases/list_transactions_having_credit_group_usecase.dart';
import '../../features/transactions/domain/usecases/search_transactions_by_description_usecase.dart';
import '../../features/transactions/domain/usecases/create_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/create_account_transfer_usecase.dart';
import '../../features/transactions/domain/usecases/update_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/delete_transaction_usecase.dart';
import '../../features/transactions/presentation/cubit/transactions_cubit.dart';
import '../../features/transactions/presentation/cubit/yearly_dashboard_cubit.dart';

final getIt = GetIt.instance;

void setupDi() {
  getIt.registerLazySingleton<AppLocaleController>(AppLocaleController.new);
  getIt.registerLazySingleton<AppThemeController>(AppThemeController.new);

  getIt.registerLazySingleton<WalletActionsDatasource>(
    () => WalletActionsDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<WalletActionsReporter>(
    () => WalletActionsReporter(
      datasource: getIt<WalletActionsDatasource>(),
    ),
  );

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
  getIt.registerFactory<AdjustAccountBalanceViaTransactionUsecase>(
    () => AdjustAccountBalanceViaTransactionUsecase(
      getCategories: getIt(),
      createCategory: getIt(),
      getTags: getIt(),
      createTag: getIt(),
      createTransaction: getIt(),
    ),
  );
  getIt.registerFactory<AccountsCubit>(
    () => AccountsCubit(
      getAccounts: getIt(),
      createAccount: getIt(),
      updateAccount: getIt(),
      deleteAccount: getIt(),
      adjustBalanceViaTransaction: getIt(),
    ),
  );

  // cards
  getIt.registerLazySingleton<CardsRemoteDatasource>(
    () => CardsSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<CardsRepository>(
    () => CardsRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetCardsUsecase>(() => GetCardsUsecase(getIt()));
  getIt.registerFactory<CreateCardUsecase>(() => CreateCardUsecase(getIt()));
  getIt.registerFactory<UpdateCardUsecase>(() => UpdateCardUsecase(getIt()));
  getIt.registerFactory<DeleteCardUsecase>(() => DeleteCardUsecase(getIt()));
  getIt.registerFactory<AdjustCardBalanceViaTransactionUsecase>(
    () => AdjustCardBalanceViaTransactionUsecase(
      getCategories: getIt(),
      createCategory: getIt(),
      getTags: getIt(),
      createTag: getIt(),
      createTransaction: getIt(),
    ),
  );
  getIt.registerFactory<CardsCubit>(
    () => CardsCubit(
      getCards: getIt(),
      createCard: getIt(),
      updateCard: getIt(),
      deleteCard: getIt(),
      adjustBalanceViaTransaction: getIt(),
    ),
  );

  // categories
  getIt.registerLazySingleton<CategoriesRemoteDatasource>(
    () => CategoriesSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<CategoriesRepository>(
    () => CategoriesRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetCategoriesUsecase>(() => GetCategoriesUsecase(getIt()));
  getIt.registerFactory<CreateCategoryUsecase>(() => CreateCategoryUsecase(getIt()));
  getIt.registerFactory<UpdateCategoryUsecase>(() => UpdateCategoryUsecase(getIt()));
  getIt.registerFactory<DeleteCategoryUsecase>(() => DeleteCategoryUsecase(getIt()));
  getIt.registerFactory<CategoriesCubit>(
    () => CategoriesCubit(
      getCategories: getIt(),
      createCategory: getIt(),
      updateCategory: getIt(),
      deleteCategory: getIt(),
    ),
  );

  // tags
  getIt.registerLazySingleton<TagsRemoteDatasource>(
    () => TagsSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<TagsRepository>(
    () => TagsRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetTagsUsecase>(() => GetTagsUsecase(getIt()));
  getIt.registerFactory<CreateTagUsecase>(() => CreateTagUsecase(getIt()));
  getIt.registerFactory<UpdateTagUsecase>(() => UpdateTagUsecase(getIt()));
  getIt.registerFactory<DeleteTagUsecase>(() => DeleteTagUsecase(getIt()));
  getIt.registerFactory<TagsCubit>(
    () => TagsCubit(
      getTags: getIt(),
      createTag: getIt(),
      updateTag: getIt(),
      deleteTag: getIt(),
    ),
  );

  // assets
  getIt.registerLazySingleton<AssetsRemoteDatasource>(
    () => AssetsSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<AssetsRepository>(
    () => AssetsRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetAssetsUsecase>(() => GetAssetsUsecase(getIt()));
  getIt.registerFactory<CreateAssetUsecase>(() => CreateAssetUsecase(getIt()));
  getIt.registerFactory<UpdateAssetUsecase>(() => UpdateAssetUsecase(getIt()));
  getIt.registerFactory<DeleteAssetUsecase>(() => DeleteAssetUsecase(getIt()));
  getIt.registerFactory<AssetsCubit>(
    () => AssetsCubit(
      getAssets: getIt(),
      createAsset: getIt(),
      updateAsset: getIt(),
      deleteAsset: getIt(),
    ),
  );

  // transactions
  getIt.registerLazySingleton<TransactionsRemoteDatasource>(
    () => TransactionsSupabaseDatasource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<TransactionsRepository>(
    () => TransactionsRepositoryImpl(getIt()),
  );
  getIt.registerFactory<GetTransactionsUsecase>(() => GetTransactionsUsecase(getIt()));
  getIt.registerFactory<GetTransactionsForYearUsecase>(() => GetTransactionsForYearUsecase(getIt()));
  getIt.registerFactory<SearchTransactionsByDescriptionUsecase>(
    () => SearchTransactionsByDescriptionUsecase(getIt()),
  );
  getIt.registerFactory<CreateTransactionUsecase>(() => CreateTransactionUsecase(getIt()));
  getIt.registerFactory<CreateAccountTransferUsecase>(() => CreateAccountTransferUsecase(getIt()));
  getIt.registerFactory<UpdateTransactionUsecase>(() => UpdateTransactionUsecase(getIt()));
  getIt.registerFactory<DeleteTransactionUsecase>(() => DeleteTransactionUsecase(getIt()));
  getIt.registerFactory<GetTransactionsByCreditGroupIdUsecase>(
    () => GetTransactionsByCreditGroupIdUsecase(getIt()),
  );
  getIt.registerFactory<ListTransactionsHavingCreditGroupUsecase>(
    () => ListTransactionsHavingCreditGroupUsecase(getIt()),
  );
  getIt.registerFactory<TransactionsCubit>(
    () => TransactionsCubit(
      getTransactions: getIt(),
      createTransaction: getIt(),
      updateTransaction: getIt(),
      deleteTransaction: getIt(),
      createAccountTransfer: getIt(),
      getTransactionsByCreditGroupId: getIt(),
    ),
  );
  getIt.registerFactory<YearlyDashboardCubit>(() => YearlyDashboardCubit(getIt()));
}
