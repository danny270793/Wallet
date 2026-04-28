// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wallet';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fieldRequired => 'Required';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get settings => 'Settings';

  @override
  String get signOut => 'Sign out';

  @override
  String get accounts => 'Accounts';

  @override
  String get noAccounts => 'No accounts yet';

  @override
  String get newAccount => 'New account';

  @override
  String get accountName => 'Name';

  @override
  String get accountDescription => 'Description';

  @override
  String get editAccount => 'Edit account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String confirmDeleteAccount(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get cards => 'Cards';

  @override
  String get noCards => 'No cards yet';

  @override
  String get newCard => 'New card';

  @override
  String get editCard => 'Edit card';

  @override
  String get deleteCard => 'Delete card';

  @override
  String confirmDeleteCard(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get categories => 'Categories';

  @override
  String get noCategories => 'No categories yet';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String confirmDeleteCategory(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get tags => 'Tags';

  @override
  String get noTags => 'No tags yet';

  @override
  String get newTag => 'New tag';

  @override
  String get editTag => 'Edit tag';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String confirmDeleteTag(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get transactions => 'Transactions';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get deleteTransaction => 'Delete transaction';

  @override
  String get confirmDeleteTransaction =>
      'Are you sure you want to delete this transaction?';

  @override
  String get none => 'None';

  @override
  String get transactionDateTime => 'When';

  @override
  String get transactionAccount => 'Account';

  @override
  String get transactionCard => 'Card';

  @override
  String get transactionCategory => 'Category';

  @override
  String get transactionTag => 'Tag';

  @override
  String get transactionAmount => 'Amount';

  @override
  String get transactionPercentage => 'Percentage';

  @override
  String get transactionIgnore => 'Ignore';

  @override
  String transactionAmountValue(String amount) {
    return '$amount';
  }
}
