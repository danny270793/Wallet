import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// No description provided for @monthlyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Monthly dashboard'**
  String get monthlyDashboard;

  /// No description provided for @monthlyDashboardTransactionsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get monthlyDashboardTransactionsListTitle;

  /// No description provided for @dashboardIncludeIgnoredInTotals.
  ///
  /// In en, this message translates to:
  /// **'Include ignored transactions'**
  String get dashboardIncludeIgnoredInTotals;

  /// No description provided for @monthlyDashboardTagPieTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses by tag'**
  String get monthlyDashboardTagPieTitle;

  /// No description provided for @monthlyDashboardCategoryPieTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses by category'**
  String get monthlyDashboardCategoryPieTitle;

  /// No description provided for @dashboardCategoryPieNoData.
  ///
  /// In en, this message translates to:
  /// **'No categorized expenses to show for this month with the current filter.'**
  String get dashboardCategoryPieNoData;

  /// No description provided for @dashboardTagPieNoData.
  ///
  /// In en, this message translates to:
  /// **'No amounts to show for this month with the current filter.'**
  String get dashboardTagPieNoData;

  /// No description provided for @dashboardTagPieFilterTags.
  ///
  /// In en, this message translates to:
  /// **'Filter tags'**
  String get dashboardTagPieFilterTags;

  /// No description provided for @dashboardTagPieFilterDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which tags are included in the chart.'**
  String get dashboardTagPieFilterDescription;

  /// No description provided for @dashboardTagPieNeedOneTag.
  ///
  /// In en, this message translates to:
  /// **'Select at least one tag'**
  String get dashboardTagPieNeedOneTag;

  /// No description provided for @dashboardCategoryPieFilterCategories.
  ///
  /// In en, this message translates to:
  /// **'Filter categories'**
  String get dashboardCategoryPieFilterCategories;

  /// No description provided for @dashboardCategoryPieFilterDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which categories are included in the chart.'**
  String get dashboardCategoryPieFilterDescription;

  /// No description provided for @dashboardCategoryPieNeedOneCategory.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category'**
  String get dashboardCategoryPieNeedOneCategory;

  /// No description provided for @dashboardPieDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get dashboardPieDeselectAll;

  /// No description provided for @dashboardPieSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get dashboardPieSelectAll;

  /// No description provided for @yearlyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Yearly dashboard'**
  String get yearlyDashboard;

  /// No description provided for @yearlyDashboardIncomeByMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Income by month'**
  String get yearlyDashboardIncomeByMonthTitle;

  /// No description provided for @yearlyDashboardOutcomeByMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Outcome by month'**
  String get yearlyDashboardOutcomeByMonthTitle;

  /// No description provided for @yearlyDashboardNetByMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance by month'**
  String get yearlyDashboardNetByMonthTitle;

  /// No description provided for @yearlyDashboardCumulativeByMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Cumulative balance by month'**
  String get yearlyDashboardCumulativeByMonthTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutApp.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutApp;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacyTagline.
  ///
  /// In en, this message translates to:
  /// **'How this app treats your information.'**
  String get settingsPrivacyTagline;

  /// No description provided for @settingsPrivacyDataTitle.
  ///
  /// In en, this message translates to:
  /// **'What you store'**
  String get settingsPrivacyDataTitle;

  /// No description provided for @settingsPrivacyDataBody.
  ///
  /// In en, this message translates to:
  /// **'Wallet keeps the financial details you enter—accounts, cards, transactions, categories, tags, and transfers—so you can see balances and history. The app does not collect data you never saved while signed in.'**
  String get settingsPrivacyDataBody;

  /// No description provided for @settingsPrivacyInfraTitle.
  ///
  /// In en, this message translates to:
  /// **'Where it lives'**
  String get settingsPrivacyInfraTitle;

  /// No description provided for @settingsPrivacyInfraBody.
  ///
  /// In en, this message translates to:
  /// **'Your records are stored in the backend you configure (for example Supabase) and the authentication you use. Security, backups, and who can access data depend on that provider and your project settings. Use strong passwords and protect API keys.'**
  String get settingsPrivacyInfraBody;

  /// No description provided for @settingsPrivacySharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing and ads'**
  String get settingsPrivacySharingTitle;

  /// No description provided for @settingsPrivacySharingBody.
  ///
  /// In en, this message translates to:
  /// **'We do not sell your personal information or use your ledger to target ads. Apart from your chosen backend and sign-in service, this app is not designed to send your data to brokers or advertisers.'**
  String get settingsPrivacySharingBody;

  /// No description provided for @settingsPrivacyNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you ship'**
  String get settingsPrivacyNoticeTitle;

  /// No description provided for @settingsPrivacyNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'This text is a simple placeholder, not legal advice. Before production or an app store release, publish a privacy policy that matches your jurisdiction, your organization, and how you actually process data.'**
  String get settingsPrivacyNoticeBody;

  /// No description provided for @settingsTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get settingsTermsOfUse;

  /// No description provided for @settingsTermsTagline.
  ///
  /// In en, this message translates to:
  /// **'Rules for using this app.'**
  String get settingsTermsTagline;

  /// No description provided for @settingsTermsAcceptanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Acceptance'**
  String get settingsTermsAcceptanceTitle;

  /// No description provided for @settingsTermsAcceptanceBody.
  ///
  /// In en, this message translates to:
  /// **'By accessing or using Wallet, you agree to these terms. If you do not agree, do not use the app.'**
  String get settingsTermsAcceptanceBody;

  /// No description provided for @settingsTermsDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Not professional advice'**
  String get settingsTermsDisclaimerTitle;

  /// No description provided for @settingsTermsDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Wallet is a tool for organizing your own records. Nothing in the app or these terms is financial, legal, accounting, or tax advice. You use the app and any information in it at your own risk when making decisions.'**
  String get settingsTermsDisclaimerBody;

  /// No description provided for @settingsTermsLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Limitation of liability'**
  String get settingsTermsLiabilityTitle;

  /// No description provided for @settingsTermsLiabilityBody.
  ///
  /// In en, this message translates to:
  /// **'To the fullest extent permitted by law, the authors and contributors are not liable for any indirect, incidental, or consequential damages, or for losses or decisions you make based on the app. The app is provided as-is without warranties of any kind.'**
  String get settingsTermsLiabilityBody;

  /// No description provided for @settingsTermsResponsibilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your responsibilities'**
  String get settingsTermsResponsibilitiesTitle;

  /// No description provided for @settingsTermsResponsibilitiesBody.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for protecting your account, credentials, API keys, and devices. You must comply with laws and regulations that apply to you, including those governing financial record-keeping and taxes in your jurisdiction.'**
  String get settingsTermsResponsibilitiesBody;

  /// No description provided for @settingsTermsNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes and before you ship'**
  String get settingsTermsNoticeTitle;

  /// No description provided for @settingsTermsNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'These terms may be updated from time to time. If you continue to use the app after changes are posted, that indicates your acceptance of the updated terms. This text is a simple placeholder, not legal advice. Before production or an app store release, publish terms that match your jurisdiction, your organization, and your service.'**
  String get settingsTermsNoticeBody;

  /// No description provided for @settingsAboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Personal finance in one place.'**
  String get settingsAboutTagline;

  /// No description provided for @settingsAboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersionLabel;

  /// No description provided for @settingsAboutFeaturesHeading.
  ///
  /// In en, this message translates to:
  /// **'What you can do'**
  String get settingsAboutFeaturesHeading;

  /// No description provided for @settingsAboutBulletAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connect accounts and cards to mirror your balances in the app.'**
  String get settingsAboutBulletAccounts;

  /// No description provided for @settingsAboutBulletLedger.
  ///
  /// In en, this message translates to:
  /// **'Log transactions, transfers, categories, and tags in a clear ledger.'**
  String get settingsAboutBulletLedger;

  /// No description provided for @settingsAboutBulletMonth.
  ///
  /// In en, this message translates to:
  /// **'Review each month and search your history when you need answers.'**
  String get settingsAboutBulletMonth;

  /// No description provided for @settingsAboutDataHeading.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsAboutDataHeading;

  /// No description provided for @settingsAboutDataBody.
  ///
  /// In en, this message translates to:
  /// **'What you save is stored in the backend you configure (for example Supabase) and is tied to your sign-in. This build is intended for personal use.'**
  String get settingsAboutDataBody;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get newAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get accountDescription;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalance;

  /// No description provided for @listBalanceTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get listBalanceTotalLabel;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @accountSubmitCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get accountSubmitCreate;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteAccount(String name);

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @noCards.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get noCards;

  /// No description provided for @newCard.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get newCard;

  /// No description provided for @editCard.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get editCard;

  /// No description provided for @deleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get deleteCard;

  /// No description provided for @confirmDeleteCard.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteCard(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategories;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteCategory(String name);

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTags;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @editTag.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get editTag;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get deleteTag;

  /// No description provided for @confirmDeleteTag.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteTag(String name);

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @transactionsSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get transactionsSearchTooltip;

  /// No description provided for @transactionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by description'**
  String get transactionsSearchHint;

  /// No description provided for @transactionsSearchTypeQuery.
  ///
  /// In en, this message translates to:
  /// **'Enter text to search all your transactions'**
  String get transactionsSearchTypeQuery;

  /// No description provided for @transactionsSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get transactionsSearchNoResults;

  /// No description provided for @transactionsPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Choose month'**
  String get transactionsPickMonth;

  /// No description provided for @transactionsPickPreviousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get transactionsPickPreviousYear;

  /// No description provided for @transactionsPickNextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get transactionsPickNextYear;

  /// No description provided for @yearlyPickYear.
  ///
  /// In en, this message translates to:
  /// **'Choose year'**
  String get yearlyPickYear;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @noTransactionsInMonth.
  ///
  /// In en, this message translates to:
  /// **'No transactions in {monthYear}'**
  String noTransactionsInMonth(String monthYear);

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get newTransaction;

  /// No description provided for @transactionsFabTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transactionsFabTransfer;

  /// No description provided for @transferSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferSheetTitle;

  /// No description provided for @transferSourceAccount.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get transferSourceAccount;

  /// No description provided for @transferTargetAccount.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get transferTargetAccount;

  /// No description provided for @transferDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transferDateLabel;

  /// No description provided for @transferTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get transferTimeLabel;

  /// No description provided for @transferAccountsMustDiffer.
  ///
  /// In en, this message translates to:
  /// **'Source and target must be different'**
  String get transferAccountsMustDiffer;

  /// No description provided for @transferNeedTwoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add at least two accounts or cards to transfer money between them'**
  String get transferNeedTwoAccounts;

  /// No description provided for @transferAccountSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get transferAccountSearch;

  /// No description provided for @transferAccountSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by account name'**
  String get transferAccountSearchHint;

  /// No description provided for @transferAccountSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No accounts match your search'**
  String get transferAccountSearchNoResults;

  /// No description provided for @editTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransferTitle;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransaction;

  /// No description provided for @confirmDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this transaction?'**
  String get confirmDeleteTransaction;

  /// No description provided for @deleteTransferPair.
  ///
  /// In en, this message translates to:
  /// **'Delete transfer'**
  String get deleteTransferPair;

  /// No description provided for @confirmDeleteTransferPair.
  ///
  /// In en, this message translates to:
  /// **'This removes both sides of the transfer from the ledger.'**
  String get confirmDeleteTransferPair;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @transactionDateTime.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get transactionDateTime;

  /// No description provided for @transactionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get transactionAccount;

  /// No description provided for @transactionCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get transactionCard;

  /// No description provided for @transactionPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get transactionPaymentMethod;

  /// No description provided for @paymentMethodAddChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add account or card'**
  String get paymentMethodAddChoiceTitle;

  /// No description provided for @transactionPaymentMethodSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No payment methods match your search'**
  String get transactionPaymentMethodSearchNoResults;

  /// No description provided for @transactionCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionCategory;

  /// No description provided for @transactionTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get transactionTag;

  /// No description provided for @transactionAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transactionAmount;

  /// No description provided for @transactionAmountInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number (optional minus sign and decimals)'**
  String get transactionAmountInvalidNumber;

  /// No description provided for @transactionAmountMustBeNonZero.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot be zero'**
  String get transactionAmountMustBeNonZero;

  /// No description provided for @transferAmountMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero'**
  String get transferAmountMustBePositive;

  /// No description provided for @transactionPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get transactionPercentage;

  /// No description provided for @transactionPercentageInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 0 to 100'**
  String get transactionPercentageInvalidRange;

  /// No description provided for @transactionIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get transactionIgnore;

  /// No description provided for @transactionIgnoredBadge.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get transactionIgnoredBadge;

  /// No description provided for @transactionAmountValue.
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String transactionAmountValue(String amount);

  /// No description provided for @transactionsTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionsTotalIncome;

  /// No description provided for @transactionsTotalOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get transactionsTotalOutcome;

  /// No description provided for @transactionsTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get transactionsTotalBalance;

  /// No description provided for @transactionsTotalsWeightedHint.
  ///
  /// In en, this message translates to:
  /// **'Weighted'**
  String get transactionsTotalsWeightedHint;

  /// No description provided for @transactionsTotalsWeightedExcludingIgnoredHint.
  ///
  /// In en, this message translates to:
  /// **'Weighted excluding ignored'**
  String get transactionsTotalsWeightedExcludingIgnoredHint;

  /// No description provided for @transactionsTotalsNotWeightedHint.
  ///
  /// In en, this message translates to:
  /// **'Not weighted'**
  String get transactionsTotalsNotWeightedHint;

  /// No description provided for @transactionsTotalsNotWeightedExcludingIgnoredHint.
  ///
  /// In en, this message translates to:
  /// **'Not weighted excluding ignored'**
  String get transactionsTotalsNotWeightedExcludingIgnoredHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
