import SwiftUI
import WalletData

/// Loading spinner, load-failure panel, or the content.
struct LoadableContent<T: Sendable, Content: View>: View {
  let state: Loadable<T>
  let retry: () async -> Void
  @ViewBuilder let content: (T) -> Content

  var body: some View {
    if let value = state.value {
      content(value)
    } else if let failure = state.failure {
      LoadFailureView(failure: failure, retry: retry)
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

struct LoadFailureView: View {
  let failure: LoadFailure
  let retry: () async -> Void

  var body: some View {
    let offline = failure == .networkUnavailable
    ContentUnavailableView {
      Label(
        L(offline ? "loadFailedNoConnectionTitle" : "loadFailedRequestFailedTitle"),
        systemImage: offline ? "wifi.slash" : "exclamationmark.icloud")
    } description: {
      Text(L(offline ? "loadFailedNoConnectionBody" : "loadFailedRequestFailedBody"))
    } actions: {
      Button(L("retry")) { Task { await retry() } }
        .buttonStyle(.glassProminent)
    }
  }
}

/// "Showing saved data" row for lists served from the offline cache.
struct OfflineBanner: View {
  var body: some View {
    Label(L("cachedDataOfflineBanner"), systemImage: "icloud.slash")
      .font(.footnote.weight(.medium))
      .foregroundStyle(.orange)
  }
}

extension View {
  /// Puts the offline banner above a list's content when [visible].
  func offlineBanner(_ visible: Bool) -> some View {
    safeAreaInset(edge: .top, spacing: 0) {
      if visible {
        OfflineBanner()
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .glassEffect(.regular.tint(.orange.opacity(0.15)), in: .capsule)
          .padding(.vertical, 6)
      }
    }
  }
}
