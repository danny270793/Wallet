import Supabase
import SwiftUI

struct LoginView: View {
  @Environment(AppModel.self) private var model
  @State private var email = ""
  @State private var password = ""
  @State private var loading = false
  @State private var error: String?
  @FocusState private var focus: Field?

  enum Field { case email, password }

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        Spacer(minLength: 40)
        Image("AppIconImage")
          .resizable().frame(width: 96, height: 96)
          .clipShape(.rect(cornerRadius: 22))
          .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        VStack(spacing: 6) {
          Text(L("signIn")).font(.largeTitle.bold())
          Text(L("signInSubtitle")).foregroundStyle(.secondary)
        }
        VStack(spacing: 12) {
          TextField(L("email"), text: $email)
            .textContentType(.username).keyboardType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focus, equals: .email).submitLabel(.next)
            .onSubmit { focus = .password }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
          SecureField(L("password"), text: $password)
            .textContentType(.password)
            .focused($focus, equals: .password).submitLabel(.go)
            .onSubmit { Task { await signIn() } }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
          if let error {
            Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        Button {
          Task { await signIn() }
        } label: {
          Group {
            if loading { ProgressView() } else { Text(L("signIn")).font(.headline) }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .disabled(loading || email.isEmpty || password.isEmpty)
      }
      .padding(24)
      .frame(maxWidth: 440)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .background {
      LinearGradient(colors: [.accentColor.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
        .ignoresSafeArea()
    }
  }

  private func signIn() async {
    guard !email.isEmpty, !password.isEmpty, let repo = model.repo else {
      error = L("fieldRequired")
      return
    }
    loading = true
    defer { loading = false }
    do {
      try await repo.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
      error = nil
      model.didSignIn()
    } catch let e as AuthError {
      error = e.message
    } catch {
      self.error = L("unexpectedError")
    }
  }
}
