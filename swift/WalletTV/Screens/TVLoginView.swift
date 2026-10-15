import SwiftUI
import WalletData

/// Sign in with email and password. tvOS offers Continuity Keyboard, so a
/// nearby iPhone can type into these fields.
struct TVLoginView: View {
  @Environment(TVModel.self) private var model
  @State private var email = ""
  @State private var password = ""
  @State private var error: String?
  @State private var loading = false

  var body: some View {
    HStack(spacing: 120) {
      VStack(alignment: .leading, spacing: 20) {
        Image(systemName: "wallet.bifold.fill").font(.system(size: 120)).foregroundStyle(.tint)
        Text(L("signIn")).font(.largeTitle.bold())
        Text(L("signInSubtitle")).font(.title3).foregroundStyle(.secondary)
      }
      VStack(spacing: 30) {
        TextField(L("email"), text: $email)
          .textContentType(.username).keyboardType(.emailAddress).autocorrectionDisabled()
        SecureField(L("password"), text: $password).textContentType(.password)
        if let error { Text(error).foregroundStyle(.red) }
        Button {
          Task { await signIn() }
        } label: {
          Group { if loading { ProgressView() } else { Text(L("signIn")) } }.frame(maxWidth: .infinity)
        }
        .disabled(loading || email.isEmpty || password.isEmpty)
      }
      .frame(width: 720)
    }
    .padding(80)
  }

  private func signIn() async {
    loading = true
    defer { loading = false }
    do {
      try await model.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
      error = nil
    } catch {
      self.error = L("unexpectedError")
      AppLog.error("tv sign in failed", error)
    }
  }
}

struct SettingsTVScreen: View {
  @Environment(TVModel.self) private var model
  @State private var confirm = false

  var body: some View {
    Form {
      Section(L("settingsProfileSection")) {
        LabeledContent(L("email"), value: model.repo?.email ?? "")
      }
      Section {
        Button(L("signOut"), role: .destructive) { confirm = true }
      }
    }
    .navigationTitle(L("settings"))
    .alert(L("signOut"), isPresented: $confirm) {
      Button(L("signOut"), role: .destructive) { Task { await model.signOut() } }
      Button(L("cancel"), role: .cancel) {}
    }
  }
}
