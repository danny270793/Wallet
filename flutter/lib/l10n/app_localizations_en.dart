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
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSpanish => 'Spanish';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get signOut => 'Sign out';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutApp => 'About';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTermsOfUse => 'Terms of use';

  @override
  String get settingsAboutBody =>
      'Wallet helps you track accounts, cards, categories, tags, and transactions in one place. Data is stored in your own backend (for example Supabase) and tied to your sign-in. This app is provided as-is for personal use.';

  @override
  String get settingsPrivacyBody =>
      'The app sends and stores only the information you enter to provide budgeting and ledger features. We do not sell your data. Technical operations (hosting, authentication, database) are handled by the services you configure. For questions about processing, contact whoever operates your project or account. Replace this text with a policy that matches your deployment before production use.';

  @override
  String get settingsTermsBody =>
      'By using Wallet you agree to use the app at your own risk. Nothing here is financial, legal, or tax advice. The authors are not liable for losses or decisions based on the app. You are responsible for securing your credentials and complying with laws that apply to you. Replace this text with your real terms before publishing.';

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
  String get accountBalance => 'Balance';

  @override
  String get listBalanceTotalLabel => 'Total';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountSubmitCreate => 'Create';

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
  String get transactionsSearchTooltip => 'Search transactions';

  @override
  String get transactionsSearchHint => 'Search by description';

  @override
  String get transactionsSearchTypeQuery =>
      'Enter text to search all your transactions';

  @override
  String get transactionsSearchNoResults => 'No matching transactions';

  @override
  String get transactionsPickMonth => 'Choose month';

  @override
  String get transactionsPickPreviousYear => 'Previous year';

  @override
  String get transactionsPickNextYear => 'Next year';

  @override
  String get year => 'Year';

  @override
  String get month => 'Month';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String noTransactionsInMonth(String monthYear) {
    return 'No transactions in $monthYear';
  }

  @override
  String get newTransaction => 'New transaction';

  @override
  String get transactionsFabTransfer => 'Transfer';

  @override
  String get transferSheetTitle => 'Transfer between accounts';

  @override
  String get transferSourceAccount => 'Source';

  @override
  String get transferTargetAccount => 'Target';

  @override
  String get transferDateLabel => 'Date';

  @override
  String get transferTimeLabel => 'Time';

  @override
  String get transferAccountsMustDiffer =>
      'Source and target must be different accounts';

  @override
  String get transferNeedTwoAccounts =>
      'Add at least two accounts to transfer money between them';

  @override
  String get transferAccountSearch => 'Search by name';

  @override
  String get transferAccountSearchHint => 'Filter by account name';

  @override
  String get transferAccountSearchNoResults => 'No accounts match your search';

  @override
  String get editTransferTitle => 'Edit transfer';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get deleteTransaction => 'Delete transaction';

  @override
  String get confirmDeleteTransaction =>
      'Are you sure you want to delete this transaction?';

  @override
  String get deleteTransferPair => 'Delete transfer';

  @override
  String get confirmDeleteTransferPair =>
      'This removes both sides of the transfer from the ledger.';

  @override
  String get none => 'None';

  @override
  String get transactionDateTime => 'When';

  @override
  String get transactionAccount => 'Account';

  @override
  String get transactionCard => 'Card';

  @override
  String get transactionPaymentMethod => 'Payment method';

  @override
  String get transactionPaymentMethodSearchNoResults =>
      'No payment methods match your search';

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
  String get transactionIgnoredBadge => 'Ignored';

  @override
  String transactionAmountValue(String amount) {
    return '$amount';
  }

  @override
  String get transactionsTotalIncome => 'Income';

  @override
  String get transactionsTotalOutcome => 'Outcome';

  @override
  String get transactionsTotalBalance => 'Balance';

  @override
  String get transactionsTotalsExcludingIgnoredHint =>
      'Excluding ignored transactions';
}
