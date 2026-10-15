import SwiftUI

/// Liquid Glass tab bar. The Flutter drawer's eleven destinations are
/// regrouped into four tabs plus the system Search tab:
/// - Activity: the month's transactions (new / transfer / pay from the toolbar);
/// - Credits: deferred card purchases;
/// - Insights: monthly and yearly dashboards;
/// - Wallet: accounts, cards, loans, recurring, assets, categories, tags, settings;
/// - Search: all-time description search, at the bottom like Apple's apps.
struct MainTabView: View {
  @State private var tab = Tabs.activity

  enum Tabs: Hashable { case activity, credits, insights, wallet, search }

  var body: some View {
    TabView(selection: $tab) {
      Tab(L("tabActivity"), systemImage: "list.bullet.rectangle.portrait", value: .activity) {
        NavigationStack { TransactionsView() }
      }
      Tab(L("creditsNav"), systemImage: "calendar.badge.clock", value: .credits) {
        CreditsView()
      }
      Tab(L("tabInsights"), systemImage: "chart.pie", value: .insights) {
        InsightsView()
      }
      Tab(L("tabWallet"), systemImage: "wallet.bifold", value: .wallet) {
        WalletHomeView()
      }
      Tab(value: .search, role: .search) {
        SearchView()
      }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewStyle(.sidebarAdaptable)
  }
}
