import SwiftUI

@main
struct WalletApp: App {
  @State private var model = AppModel()
  @State private var prefs = Preferences()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .environment(prefs)
        .environment(\.locale, L10n.locale)
        .preferredColorScheme(prefs.theme.colorScheme)
        // Rebuild every screen when the language changes so all strings refresh.
        .id(prefs.language)
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(Preferences.self) private var prefs
  @Environment(\.scenePhase) private var scenePhase
  @State private var locked = false
  @State private var wasBackgrounded = false

  var body: some View {
    Group {
      if model.isSignedIn {
        MainTabView()
      } else if model.repo == nil {
        // No Supabase config: the demo is still available from here.
        ContentUnavailableView {
          Label(L("configMissingTitle"), systemImage: "server.rack")
        } description: {
          Text(L("configMissingBody"))
        } actions: {
          Button(L("swiftDemoTry")) { model.startDemo() }.buttonStyle(.glass)
        }
      } else {
        LoginView()
      }
    }
    .overlay {
      if locked {
        BiometricLockView { locked = false }
          .transition(.opacity)
      }
    }
    .animation(.smooth, value: locked)
    .animation(.smooth, value: model.isSignedIn)
    .onChange(of: scenePhase) { _, phase in
      // Lock only after the app really went to the background, not on cold start.
      if phase == .background {
        wasBackgrounded = true
      } else if phase == .active, wasBackgrounded {
        wasBackgrounded = false
        if model.isSignedIn, prefs.biometricUnlock, prefs.biometricAvailable { locked = true }
      }
    }
    .alert(
      L("unexpectedError"), isPresented: Binding(get: { model.actionError != nil }, set: { _ in model.actionError = nil })
    ) {
      Button(L("dialogClose"), role: .cancel) {}
    }
  }
}

/// Full-screen gate shown on resume while biometric unlock is on.
struct BiometricLockView: View {
  @Environment(Preferences.self) private var prefs
  let onUnlocked: () -> Void
  @State private var busy = false

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "lock.fill")
        .font(.system(size: 52))
        .foregroundStyle(.tint)
      Text(L("biometricLockTitle")).font(.title2.bold())
      Text(L("biometricLockBody"))
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button {
        Task { await unlock() }
      } label: {
        Label(L("biometricLockUnlockButton"), systemImage: "faceid")
          .padding(.horizontal, 8)
      }
      .buttonStyle(.glassProminent)
      .controlSize(.large)
      .disabled(busy)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.background)
    .task { await unlock() }
  }

  private func unlock() async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    if !prefs.biometricUnlock || !prefs.biometricAvailable {
      onUnlocked()
      return
    }
    if await prefs.authenticate(reason: L("settingsBiometricResumeReason")) { onUnlocked() }
  }
}
