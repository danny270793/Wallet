import SwiftUI
import WalletCore
import WalletData

@main
struct WalletTVApp: App {
  @State private var model = TVModel()

  var body: some Scene {
    WindowGroup {
      TVRootView()
        .environment(model)
        .environment(\.locale, L10n.locale)
    }
  }
}

/// SwiftUI also has a `Transaction`; here the name means a ledger row.
typealias Transaction = WalletCore.Transaction

struct TVRootView: View {
  @Environment(TVModel.self) private var model

  var body: some View {
    if model.repo == nil {
      ContentUnavailableView(L("configMissingTitle"), systemImage: "server.rack", description: Text(L("configMissingBody")))
    } else if model.isSignedIn {
      // tvOS top tab bar; content is for viewing, editing stays on iPhone/Watch.
      TabView {
        Tab(L("tabOverview"), systemImage: "square.grid.2x2") { NavigationStack { OverviewScreen() } }
        Tab(L("tabActivity"), systemImage: "list.bullet.rectangle.portrait") { NavigationStack { ActivityScreen() } }
        Tab(L("creditsNav"), systemImage: "calendar.badge.clock") { NavigationStack { CreditsTVScreen() } }
        Tab(L("tabInsights"), systemImage: "chart.pie") { NavigationStack { InsightsTVScreen() } }
        Tab(L("settings"), systemImage: "gearshape") { NavigationStack { SettingsTVScreen() } }
      }
      .task(id: model.month) { await model.load() }
    } else {
      TVLoginView()
    }
  }
}
