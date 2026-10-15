#if os(iOS) || os(watchOS)
  import Foundation
  import WatchConnectivity

  private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
  }

  /// Moves the signed-in session between the iPhone and the Apple Watch.
  ///
  /// The iPhone pushes its tokens (or a sign-out) as application context,
  /// which the system delivers even if the watch app isn't running. The watch
  /// also asks for them on launch, in case the context was never received.
  public final class SessionBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    public static let shared = SessionBridge()

    /// Called on the watch when the iPhone sends tokens (nil = signed out).
    public var onTokens: (@Sendable (SessionTokens?) -> Void)?
    /// Called on the iPhone to answer the watch's request.
    public var currentTokens: (@Sendable () async -> SessionTokens?)?

    private static let key = "session"

    public func activate() {
      guard WCSession.isSupported() else { return }
      WCSession.default.delegate = self
      WCSession.default.activate()
    }

    /// iPhone side: share the current session (or sign-out) with the watch.
    public func send(_ tokens: SessionTokens?) {
      let s = WCSession.default
      guard WCSession.isSupported(), s.activationState == .activated else { return }
      #if os(iOS)
        guard s.isPaired, s.isWatchAppInstalled else { return }
      #endif
      try? s.updateApplicationContext([Self.key: Self.encode(tokens)])
    }

    /// Watch side: ask the iPhone for its session right now.
    public func request() {
      let s = WCSession.default
      guard WCSession.isSupported(), s.activationState == .activated, s.isReachable else { return }
      s.sendMessage(["request": Self.key], replyHandler: { [weak self] reply in
        self?.deliver(reply)
      }, errorHandler: nil)
    }

    private static func encode(_ tokens: SessionTokens?) -> Data {
      (try? JSONEncoder().encode(tokens)) ?? Data()
    }

    private func deliver(_ payload: [String: Any]) {
      guard let data = payload[Self.key] as? Data else { return }
      onTokens?(try? JSONDecoder().decode(SessionTokens?.self, from: data) ?? nil)
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
      #if os(watchOS)
        if !session.receivedApplicationContext.isEmpty { deliver(session.receivedApplicationContext) }
        request()
      #else
        // Already signed in at launch: no auth change will fire, so send now.
        sendCurrent()
      #endif
    }

    #if os(iOS)
      /// Sends whatever session the iPhone has right now.
      private func sendCurrent() {
        guard let currentTokens else { return }
        Task { send(await currentTokens()) }
      }
    #endif

    /// The other side came into reach: the watch asks again, the iPhone resends.
    public func sessionReachabilityDidChange(_ session: WCSession) {
      guard session.isReachable else { return }
      #if os(watchOS)
        request()
      #else
        sendCurrent()
      #endif
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
      deliver(context)
    }

    public func session(
      _ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void
    ) {
      guard message["request"] as? String == Self.key, let currentTokens else {
        replyHandler([:])
        return
      }
      // WatchConnectivity hands over a non-Sendable reply handler; box it so it
      // can be called once the tokens are ready.
      let reply = UncheckedBox(replyHandler)
      Task { reply.value([Self.key: Self.encode(await currentTokens())]) }
    }

    #if os(iOS)
      public func sessionDidBecomeInactive(_ session: WCSession) {}
      public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
      /// The watch app was just installed (or the watch paired): share the session.
      public func sessionWatchStateDidChange(_ session: WCSession) { sendCurrent() }
    #endif
  }
#endif
