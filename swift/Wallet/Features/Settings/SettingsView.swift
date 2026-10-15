import StoreKit
import SwiftUI
import WalletCore
import WalletData

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(Preferences.self) private var prefs
  @State private var changingEmail = false
  @State private var changingPassword = false
  @State private var confirmSignOut = false
  @State private var notice: String?
  @Environment(\.requestReview) private var requestReview

  var body: some View {
    @Bindable var prefs = prefs
    Form {
      Section(L("settingsProfileSection")) {
        LabeledContent(L("email"), value: model.repo?.email ?? "")
        Button(L("settingsChangeEmail")) { changingEmail = true }
        Button {
          changingPassword = true
        } label: {
          VStack(alignment: .leading) {
            Text(L("settingsChangePassword"))
            Text(L("settingsChangePasswordSubtitle")).font(.caption).foregroundStyle(.secondary)
          }
        }
      }

      Section(L("settingsSecuritySection")) {
        Toggle(isOn: Binding(get: { prefs.biometricUnlock }, set: { on in Task { await setBiometric(on) } })) {
          VStack(alignment: .leading) {
            Text(L("settingsBiometricUnlockTitle"))
            Text(L(prefs.biometricAvailable ? "settingsBiometricUnlockSubtitle" : "settingsBiometricUnavailable"))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        .disabled(!prefs.biometricAvailable && !prefs.biometricUnlock)
      }

      Section(L("settingsAppearance")) {
        Picker(L("settingsLanguage"), selection: $prefs.language) {
          ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
        }
        Picker(L("settingsTheme"), selection: $prefs.theme) {
          ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
        }
      }

      Section(L("settingsDataSection")) {
        NavigationLink {
          CacheView()
        } label: {
          VStack(alignment: .leading) {
            Text(L("settingsOfflineCache"))
            Text(L("settingsOfflineCacheSubtitle")).font(.caption).foregroundStyle(.secondary)
          }
        }
      }

      Section(L("settingsAboutSection")) {
        NavigationLink(L("settingsAboutApp")) { LegalView(kind: .about) }
        Button(L("rateApp")) { requestReview() }
        NavigationLink(L("settingsPrivacyPolicy")) { LegalView(kind: .privacy) }
        NavigationLink(L("settingsTermsOfUse")) { LegalView(kind: .terms) }
      }

      Section {
        Button(L("signOut"), role: .destructive) { confirmSignOut = true }
          .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(L("settings"))
    .confirmationDialog(L("signOut"), isPresented: $confirmSignOut) {
      Button(L("signOut"), role: .destructive) { Task { await model.signOut() } }
    }
    .sheet(isPresented: $changingEmail) { ChangeEmailSheet { notice = L("settingsChangeEmailSuccess") } }
    .sheet(isPresented: $changingPassword) { ChangePasswordSheet { notice = L("settingsChangePasswordSuccess") } }
    .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
      Button(L("dialogClose"), role: .cancel) {}
    }
  }

  private func setBiometric(_ on: Bool) async {
    if !on {
      prefs.biometricUnlock = false
      return
    }
    guard prefs.biometricAvailable else {
      notice = L("settingsBiometricUnavailable")
      return
    }
    if await prefs.authenticate(reason: L("settingsBiometricAuthReason")) { prefs.biometricUnlock = true }
  }
}

struct ChangeEmailSheet: View {
  @Environment(AppModel.self) private var model
  let onDone: () -> Void
  @State private var email = ""
  @State private var error: String?

  var body: some View {
    let t = email.trimmingCharacters(in: .whitespaces)
    let valid = t.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    EditorForm(title: L("settingsChangeEmailDialogTitle"), canSave: valid) {
      if t.lowercased() == model.repo?.email?.lowercased() {
        error = L("settingsChangeEmailSameAsCurrent")
        return false
      }
      do {
        try await model.repo?.updateEmail(t)
        onDone()
        return true
      } catch {
        self.error = L("unexpectedError")
        return false
      }
    } content: {
      TextField(L("settingsNewEmailLabel"), text: $email)
        .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
      if !t.isEmpty && !valid { Text(L("settingsChangeEmailInvalid")).font(.caption).foregroundStyle(.red) }
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
    }
    .presentationDetents([.medium])
  }
}

struct ChangePasswordSheet: View {
  @Environment(AppModel.self) private var model
  let onDone: () -> Void
  @State private var password = ""
  @State private var confirm = ""
  @State private var error: String?

  var body: some View {
    let tooShort = !password.isEmpty && password.count < 6
    let mismatch = !confirm.isEmpty && confirm != password
    EditorForm(title: L("settingsChangePasswordDialogTitle"), canSave: password.count >= 6 && confirm == password) {
      do {
        try await model.repo?.updatePassword(password)
        onDone()
        return true
      } catch {
        self.error = L("unexpectedError")
        return false
      }
    } content: {
      SecureField(L("settingsNewPasswordLabel"), text: $password).textContentType(.newPassword)
      if tooShort { Text(L("settingsPasswordTooShort")).font(.caption).foregroundStyle(.red) }
      SecureField(L("settingsConfirmNewPasswordLabel"), text: $confirm).textContentType(.newPassword)
      if mismatch { Text(L("settingsPasswordsDoNotMatch")).font(.caption).foregroundStyle(.red) }
      if let error { Text(error).font(.caption).foregroundStyle(.red) }
    }
    .presentationDetents([.medium])
  }
}

/// Offline cache files with sizes, sortable by date, size or name.
struct CacheView: View {
  @Environment(AppModel.self) private var model
  enum SortBy: CaseIterable { case date, size, name }
  @State private var entries: [CacheEntry] = []
  @State private var sort: SortBy = .date

  var body: some View {
    let sorted: [CacheEntry] =
      switch sort {
      case .date: entries.sorted { $0.modifiedAt > $1.modifiedAt }
      case .size: entries.sorted { $0.bytes > $1.bytes }
      case .name: entries.sorted { label($0.key).lowercased() < label($1.key).lowercased() }
      }
    List {
      if entries.isEmpty {
        ContentUnavailableView(L("settingsCacheEmpty"), systemImage: "externaldrive").listRowBackground(Color.clear)
      }
      ForEach(sorted) { e in
        VStack(alignment: .leading, spacing: 2) {
          Text(label(e.key))
          Text("\(ByteCountFormatter.string(fromByteCount: Int64(e.bytes), countStyle: .file)) · \(e.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(L("settingsCachePageTitle"))
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu(L("settingsCacheSortTooltip"), systemImage: "arrow.up.arrow.down") {
          Picker(L("settingsCacheSortSheetTitle"), selection: $sort) {
            Text(L("settingsCacheSortByDate")).tag(SortBy.date)
            Text(L("settingsCacheSortBySize")).tag(SortBy.size)
            Text(L("settingsCacheSortByName")).tag(SortBy.name)
          }
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if !entries.isEmpty {
        let total = entries.reduce(0) { $0 + $1.bytes }
        VStack(spacing: 2) {
          Text(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)).font(.headline).monospacedDigit()
          Text(L("settingsCacheBottomBarCaption")).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .padding(.horizontal, 16)
      }
    }
    .task { entries = await model.repo?.cacheEntries() ?? [] }
  }

  /// Human label for a cache key, as in the Flutter app.
  private func label(_ key: String) -> String {
    if let m = key.wholeMatch(of: /tx_month_(\d+)_(\d+)/) { return L("settingsCacheKeyTxMonth", m.1, m.2) }
    if let m = key.wholeMatch(of: /tx_year_(\d+)/) { return L("settingsCacheKeyTxYear", m.1) }
    if key == CacheKey.creditGroups { return L("settingsCacheKeyTxCreditGroups") }
    if let m = key.wholeMatch(of: /tx_credit_(.+)/) { return L("settingsCacheKeyTxCredit", m.1.prefix(8)) }
    if let m = key.wholeMatch(of: /wallet_credit_(.+)/) { return L("settingsCacheKeyWalletCredit", m.1.prefix(8)) }
    let known = [
      "accounts": "accounts", "cards": "cards", "loans": "loans", "categories": "categories", "tags": "tags",
      "assets": "assets", "recurring_movements": "recurringMovements", "loan_capital_payments": "loanCapitalPayment",
    ]
    return known[key].map { L($0) } ?? key
  }
}
