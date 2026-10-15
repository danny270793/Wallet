import SwiftUI
import WalletCore

@main
struct WalletWatchApp: App {
  @State private var model = WatchModel()

  var body: some Scene {
    WindowGroup {
      WatchRootView()
        .environment(model)
        .environment(\.locale, L10n.locale)
    }
  }
}

/// SwiftUI also has a `Transaction`; here the name means a ledger row.
typealias Transaction = WalletCore.Transaction

struct WatchRootView: View {
  @Environment(WatchModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  /// Debug builds accept `-watchPage 0…4` (handy for simulator screenshots).
  @State private var page: Int = {
    #if DEBUG
      UserDefaults.standard.integer(forKey: "watchPage")
    #else
      0
    #endif
  }()

  var body: some View {
    content
      .onChange(of: scenePhase, initial: true) { _, phase in
        if phase == .active { model.refreshSessionFromPhone() }
      }
  }

  @ViewBuilder private var content: some View {
    if model.repo == nil {
      ContentUnavailableView(L("configMissingTitle"), systemImage: "server.rack")
    } else if model.isSignedIn {
      // Vertical pages, the watchOS 26 layout for an app's main screens.
      TabView(selection: $page) {
        // Glanceable first (month, year, credits), then the list and the form.
        NavigationStack { SummaryScreen() }.tag(0)
        NavigationStack { YearScreen() }.tag(1)
        NavigationStack { CreditsScreen() }.tag(2)
        NavigationStack { RecentScreen() }.tag(3)
        NavigationStack { QuickAddScreen() }.tag(4)
      }
      .tabViewStyle(.verticalPage)
      .task { await model.load() }
    } else {
      SignInHintView()
    }
  }
}

/// No login on the watch: it waits for the session from the iPhone app.
struct SignInHintView: View {
  @Environment(WatchModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        Image(systemName: "iphone.and.arrow.forward")
          .font(.system(size: 34))
          .foregroundStyle(.tint)
        Text(L("watchSignInTitle")).font(.headline).multilineTextAlignment(.center)
        Text(L("watchSignInBody")).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        Button(L("retry")) { model.retrySessionRequest() }
          .buttonStyle(.glassProminent)
      }
      .padding()
    }
  }
}
