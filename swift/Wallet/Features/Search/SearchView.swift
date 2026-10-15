import SwiftUI
import WalletCore

/// The Search tab: all-time description search with the system bottom
/// search field (Liquid Glass `Tab(role: .search)`). Results are grouped by
/// day; tapping one opens its editor.
struct SearchView: View {
  @Environment(AppModel.self) private var model
  @State private var query = ""
  @State private var results: [Transaction]?
  @State private var failed = false
  @State private var editor: EditorRoute?

  var body: some View {
    NavigationStack {
      List {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
          ContentUnavailableView(L("transactionsSearchTooltip"), systemImage: "magnifyingglass",
                                 description: Text(L("transactionsSearchTypeQuery")))
            .listRowBackground(Color.clear)
        } else if let results {
          if failed && results.isEmpty {
            Text(L("unexpectedError")).foregroundStyle(.red)
          } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
              .listRowBackground(Color.clear)
          } else {
            LedgerSections(days: Ledger.groupedByDay(results), editor: $editor)
          }
        } else {
          ProgressView().frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
      }
      .navigationTitle(L("tabSearch"))
      .searchable(text: $query, prompt: L("transactionsSearchHint"))
      .task(id: "\(query)-\(model.dataVersion)") { await search() }
      .ledgerEditors($editor)
    }
  }

  /// Debounced (like the Flutter app) so typing doesn't fire a query per key.
  private func search() async {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else {
      results = nil
      return
    }
    results = nil
    try? await Task.sleep(for: .milliseconds(450))
    guard !Task.isCancelled, let repo = model.repo else { return }
    do {
      let found = try await repo.searchTransactions(q)
      guard !Task.isCancelled else { return }
      results = found
      failed = false
    } catch is CancellationError {
    } catch {
      failed = true
      results = []
    }
  }
}
