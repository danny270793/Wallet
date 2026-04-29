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
  String get monthlyDashboard => 'Monthly dashboard';

  @override
  String get monthlyDashboardConfigureTooltip => 'Charts and totals options';

  @override
  String get monthlyDashboardOptionsSheetTitle => 'View options';

  @override
  String get monthlyDashboardTransactionsListTitle => 'Transactions';

  @override
  String get dashboardIncludeIgnoredInTotals => 'Include ignored transactions';

  @override
  String get dashboardUseWeightedAmounts => 'Weighted amounts (%)';

  @override
  String get monthlyDashboardTagPieTitle => 'Expenses by tag';

  @override
  String get monthlyDashboardCategoryPieTitle => 'Expenses by category';

  @override
  String get dashboardCategoryPieNoData =>
      'No categorized expenses to show for this month with the current filter.';

  @override
  String get dashboardTagPieNoData =>
      'No amounts to show for this month with the current filter.';

  @override
  String get dashboardTagPieFilterTags => 'Filter tags';

  @override
  String get dashboardTagPieFilterDescription =>
      'Choose which tags are included in the chart.';

  @override
  String get dashboardTagPieNeedOneTag => 'Select at least one tag';

  @override
  String get dashboardCategoryPieFilterCategories => 'Filter categories';

  @override
  String get dashboardCategoryPieFilterDescription =>
      'Choose which categories are included in the chart.';

  @override
  String get dashboardCategoryPieNeedOneCategory =>
      'Select at least one category';

  @override
  String get dashboardPieDeselectAll => 'Deselect all';

  @override
  String get dashboardPieSelectAll => 'Select all';

  @override
  String get yearlyDashboard => 'Yearly dashboard';

  @override
  String get yearlyDashboardIncomeByMonthTitle => 'Income by month';

  @override
  String get yearlyDashboardOutcomeByMonthTitle => 'Outcome by month';

  @override
  String get yearlyDashboardNetByMonthTitle => 'Balance by month';

  @override
  String get yearlyDashboardCumulativeByMonthTitle =>
      'Cumulative balance by month';

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
  String get settingsPrivacyTagline => 'How this app treats your information.';

  @override
  String get settingsPrivacyDataTitle => 'What you store';

  @override
  String get settingsPrivacyDataBody =>
      'Wallet keeps the financial details you enter—accounts, cards, transactions, categories, tags, and transfers—so you can see balances and history. The app does not collect data you never saved while signed in.';

  @override
  String get settingsPrivacyInfraTitle => 'Where it lives';

  @override
  String get settingsPrivacyInfraBody =>
      'Your records are stored in the backend you configure (for example Supabase) and the authentication you use. Security, backups, and who can access data depend on that provider and your project settings. Use strong passwords and protect API keys.';

  @override
  String get settingsPrivacySharingTitle => 'Sharing and ads';

  @override
  String get settingsPrivacySharingBody =>
      'We do not sell your personal information or use your ledger to target ads. Apart from your chosen backend and sign-in service, this app is not designed to send your data to brokers or advertisers.';

  @override
  String get settingsPrivacyNoticeTitle => 'Before you ship';

  @override
  String get settingsPrivacyNoticeBody =>
      'This text is a simple placeholder, not legal advice. Before production or an app store release, publish a privacy policy that matches your jurisdiction, your organization, and how you actually process data.';

  @override
  String get settingsTermsOfUse => 'Terms of use';

  @override
  String get settingsTermsTagline => 'Rules for using this app.';

  @override
  String get settingsTermsAcceptanceTitle => 'Acceptance';

  @override
  String get settingsTermsAcceptanceBody =>
      'By accessing or using Wallet, you agree to these terms. If you do not agree, do not use the app.';

  @override
  String get settingsTermsDisclaimerTitle => 'Not professional advice';

  @override
  String get settingsTermsDisclaimerBody =>
      'Wallet is a tool for organizing your own records. Nothing in the app or these terms is financial, legal, accounting, or tax advice. You use the app and any information in it at your own risk when making decisions.';

  @override
  String get settingsTermsLiabilityTitle => 'Limitation of liability';

  @override
  String get settingsTermsLiabilityBody =>
      'To the fullest extent permitted by law, the authors and contributors are not liable for any indirect, incidental, or consequential damages, or for losses or decisions you make based on the app. The app is provided as-is without warranties of any kind.';

  @override
  String get settingsTermsResponsibilitiesTitle => 'Your responsibilities';

  @override
  String get settingsTermsResponsibilitiesBody =>
      'You are responsible for protecting your account, credentials, API keys, and devices. You must comply with laws and regulations that apply to you, including those governing financial record-keeping and taxes in your jurisdiction.';

  @override
  String get settingsTermsNoticeTitle => 'Changes and before you ship';

  @override
  String get settingsTermsNoticeBody =>
      'These terms may be updated from time to time. If you continue to use the app after changes are posted, that indicates your acceptance of the updated terms. This text is a simple placeholder, not legal advice. Before production or an app store release, publish terms that match your jurisdiction, your organization, and your service.';

  @override
  String get settingsAboutTagline => 'Personal finance in one place.';

  @override
  String get settingsAboutVersionLabel => 'Version';

  @override
  String get settingsAboutFeaturesHeading => 'What you can do';

  @override
  String get settingsAboutBulletAccounts =>
      'Connect accounts and cards to mirror your balances in the app.';

  @override
  String get settingsAboutBulletLedger =>
      'Log transactions, transfers, categories, and tags in a clear ledger.';

  @override
  String get settingsAboutBulletMonth =>
      'Review each month and search your history when you need answers.';

  @override
  String get settingsAboutDataHeading => 'Your data';

  @override
  String get settingsAboutDataBody =>
      'What you save is stored in the backend you configure (for example Supabase) and is tied to your sign-in. This build is intended for personal use.';

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
  String get assets => 'Assets';

  @override
  String get noAssets => 'No assets yet';

  @override
  String get assetSold => 'Sold';

  @override
  String get newAsset => 'New asset';

  @override
  String get assetProvider => 'Provider';

  @override
  String get assetValue => 'Value';

  @override
  String get assetPurchaseDate => 'Purchase date';

  @override
  String get assetEndDate => 'End date';

  @override
  String get assetSoldAmountField => 'Sold amount';

  @override
  String get assetInvalidNumber => 'Enter a valid number';

  @override
  String get assetEndBeforePurchase =>
      'End date must be on or after purchase date';

  @override
  String assetHeldDuration(String duration) {
    return 'Held $duration';
  }

  @override
  String get editAsset => 'Edit asset';

  @override
  String get deleteAsset => 'Delete asset';

  @override
  String confirmDeleteAsset(String name) {
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
  String get yearlyPickYear => 'Choose year';

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
  String get transferSheetTitle => 'Transfer';

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
      'Source and target must be different';

  @override
  String get transferNeedTwoAccounts =>
      'Add at least two accounts or cards to transfer money between them';

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
  String get paymentMethodAddChoiceTitle => 'Add account or card';

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
  String get transactionAmountInvalidNumber =>
      'Enter a valid number (optional minus sign and decimals)';

  @override
  String get transactionAmountMustBeNonZero => 'Amount cannot be zero';

  @override
  String get transferAmountMustBePositive =>
      'Enter an amount greater than zero';

  @override
  String get transactionPercentage => 'Percentage';

  @override
  String get transactionPercentageInvalidRange =>
      'Enter a number from 0 to 100';

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
  String get transactionsTotalsWeightedHint => 'Weighted';

  @override
  String get transactionsTotalsWeightedExcludingIgnoredHint =>
      'Weighted excluding ignored';

  @override
  String get transactionsTotalsNotWeightedHint => 'Not weighted';

  @override
  String get transactionsTotalsNotWeightedExcludingIgnoredHint =>
      'Not weighted excluding ignored';
}
