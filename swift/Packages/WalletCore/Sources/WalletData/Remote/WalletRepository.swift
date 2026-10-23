import Foundation
import Supabase
import WalletCore

/// Supabase credentials read from `WalletConfig.plist` (see `swift/README.md`).
public struct WalletConfig: Sendable {
  public var url: URL
  public var anonKey: String

  public init(url: URL, anonKey: String) {
    self.url = url
    self.anonKey = anonKey
  }

  public static func fromBundle(_ bundle: Bundle = .main) -> WalletConfig? {
    guard let path = bundle.path(forResource: "WalletConfig", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: String],
      let raw = dict["SUPABASE_URL"], let url = URL(string: raw), let key = dict["SUPABASE_ANON_KEY"],
      !key.isEmpty, !raw.contains("xxxx")
    else { return nil }
    return WalletConfig(url: url, anonKey: key)
  }
}

/// The parts of a Supabase session needed to restore it on another device.
public struct SessionTokens: Codable, Hashable, Sendable {
  public var accessToken: String
  public var refreshToken: String
  public init(accessToken: String, refreshToken: String) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public enum WalletError: LocalizedError {
  case notSignedIn
  case softDeleteFailed(String)
  case invalidArgument(String)

  public var errorDescription: String? {
    switch self {
    case .notSignedIn: "Not signed in"
    case .softDeleteFailed(let s): "\(s): no row updated"
    case .invalidArgument(let s): s
    }
  }
}

/// Every read and write the app does against the `wallet_*` schema.
///
/// Mirrors the Flutter datasources + repositories: reads go through the
/// offline cache, writes go straight to Supabase, deletes are soft (RPC).
public final class WalletRepository: Sendable {
  public let client: SupabaseClient
  let cache: OfflineCache

  /// Token borrowed from the iPhone (watch only); nil on the iPhone.
  let borrowed: BorrowedToken?

  /// In-memory ledger of demo mode; nil for a real repository. Every method
  /// answers from it first, so a demo repository never reaches Supabase.
  let demo: DemoStore?

  /// With [borrowsSession] (the watch) the client doesn't sign in at all: every
  /// request carries the access token the paired iPhone handed over. Supabase
  /// Auth on the watch would refresh with the iPhone's refresh token, which the
  /// iPhone rotates, and the server rejects ("session not found").
  public init(config: WalletConfig, cache: OfflineCache = .shared, borrowsSession: Bool = false) {
    let token = borrowsSession ? BorrowedToken() : nil
    borrowed = token
    demo = nil
    client = SupabaseClient(
      supabaseURL: config.url, supabaseKey: config.anonKey,
      options: SupabaseClientOptions(
        db: .init(encoder: WalletJSON.encoder, decoder: WalletJSON.decoder),
        auth: token.map { t in
          .init(
            storage: KeychainLocalStorage(service: "io.github.danny270793.wallet.watch"),
            accessToken: { t.accessToken })
        }
          ?? .init(
            storage: KeychainLocalStorage(service: "io.github.danny270793.wallet.auth"),
            emitLocalSessionAsInitialSession: true)))
    self.cache = cache
    AppLog.reporter = ActionsReporter(client: client, userId: { token?.userId })
  }

  /// A demo repository: fake data in memory, no network, no disk cache and no
  /// error reporting. Its client points at an address that never resolves and
  /// is never used.
  public init(demo store: DemoStore) {
    demo = store
    borrowed = nil
    client = SupabaseClient(
      supabaseURL: URL(string: "https://demo.invalid")!, supabaseKey: "demo",
      options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage(), autoRefreshToken: false)))
    cache = OfflineCache(
      root: FileManager.default.temporaryDirectory.appendingPathComponent("wallet_demo_unused", isDirectory: true))
  }

  public var isDemo: Bool { demo != nil }

  // MARK: Session

  /// Lower-case uuid, as stored in `userId` columns.
  public var userId: String? {
    if demo != nil { return DemoDataGenerator.userId }
    if let borrowed { return borrowed.userId }
    return client.auth.currentUser?.id.uuidString.lowercased()
  }
  public var email: String? {
    if demo != nil { return DemoDataGenerator.email }
    return borrowed == nil ? client.auth.currentUser?.email : nil
  }
  public var hasSession: Bool {
    if demo != nil { return true }
    if let borrowed { return borrowed.isValid }
    return client.auth.currentSession != nil
  }

  private func requireUser() throws -> String {
    guard let id = userId else { throw WalletError.notSignedIn }
    return id
  }

  public func signIn(email: String, password: String) async throws {
    if demo != nil { throw WalletError.invalidArgument("demo mode has no account") }
    AppLog.debug("signIn called")
    try await client.auth.signIn(email: email, password: password)
  }

  /// Signs out and removes the user's offline cache.
  public func signOut() async throws {
    if demo != nil { return }
    let uid = userId
    if let borrowed {
      borrowed.clear()
    } else {
      try await client.auth.signOut()
    }
    if let uid { await cache.clear(user: uid) }
  }

  /// A session that is valid right now (refreshed first if it expired), for the watch.
  public func freshSessionTokens() async -> SessionTokens? {
    guard demo == nil else { return nil }
    guard let session = try? await client.auth.session else { return nil }
    return SessionTokens(accessToken: session.accessToken, refreshToken: session.refreshToken)
  }

  /// Watch: use the access token from the paired iPhone for every request.
  public func adopt(_ tokens: SessionTokens) throws {
    guard let borrowed else { throw WalletError.invalidArgument("only the watch borrows a session") }
    try borrowed.set(tokens.accessToken)
  }

  /// When the borrowed access token stops working (watch only).
  public var accessTokenExpiry: Date? { borrowed?.expiry }

  public func updateEmail(_ email: String) async throws {
    if demo != nil { throw WalletError.invalidArgument("demo mode has no account") }
    try await client.auth.update(user: UserAttributes(email: email))
  }

  public func updatePassword(_ password: String) async throws {
    if demo != nil { throw WalletError.invalidArgument("demo mode has no account") }
    try await client.auth.update(user: UserAttributes(password: password))
  }

  public func cacheEntries() async -> [CacheEntry] {
    guard demo == nil else { return [] }
    guard let uid = userId else { return [] }
    return await cache.entries(user: uid)
  }

  private func softDelete(_ fn: String, id: String) async throws {
    let ok: Bool = try await client.rpc(fn, params: ["p_id": id]).execute().value
    if !ok { throw WalletError.softDeleteFailed(fn) }
  }

  private func cached<T: Codable & Sendable>(_ key: String, _ remote: () async throws -> [T]) async throws
    -> Served<[T]>
  {
    try await readThrough(user: userId, key: key, cache: cache, remote: remote)
  }

  // MARK: Accounts

  public func accounts() async throws -> Served<[Account]> {
    if let demo { return Served(await demo.listAccounts(), fromCache: false) }
    return try await cached(CacheKey.accounts) {
      try await client.from("wallet_accounts_with_balance")
        .select("id, userId, name, createdAt, updatedAt, deletedAt, balance")
        .is("deletedAt", value: nil).order("createdAt").execute().value
    }
  }

  @discardableResult
  public func createAccount(name: String) async throws -> Account {
    if let demo { return await demo.createAccount(name: name) }
    struct Row: Encodable { var userId: String, name: String }
    return try await client.from("wallet_accounts").insert(Row(userId: requireUser(), name: name))
      .select().single().execute().value
  }

  public func updateAccount(id: String, name: String) async throws {
    if let demo { return await demo.updateAccount(id: id, name: name) }
    try await client.from("wallet_accounts").update(["name": name]).eq("id", value: id).execute()
  }

  public func deleteAccount(id: String) async throws {
    if let demo { return try await demo.deleteAccount(id: id) }
    try await softDelete("soft_delete_wallet_account", id: id)
  }

  // MARK: Cards

  public func cards() async throws -> Served<[Card]> {
    if let demo { return Served(await demo.listCards(), fromCache: false) }
    return try await cached(CacheKey.cards) {
      try await client.from("wallet_cards_with_balance")
        .select(
          "id, userId, name, type, cutDay, payDay, nominalInterestRate, createdAt, updatedAt, deletedAt, balance"
        )
        .is("deletedAt", value: nil).order("createdAt").execute().value
    }
  }

  struct CardRow: Encodable {
    var userId: String?
    var name: String
    var type: String
    var cutDay: Int
    var payDay: Int
    var nominalInterestRate: Double?

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encodeIfPresent(userId, forKey: .userId)
      try c.encode(name, forKey: .name)
      try c.encode(type, forKey: .type)
      try c.encode(cutDay, forKey: .cutDay)
      try c.encode(payDay, forKey: .payDay)
      try c.encode(nominalInterestRate, forKey: .nominalInterestRate)  // explicit null clears it
    }
    enum CodingKeys: String, CodingKey { case userId, name, type, cutDay, payDay, nominalInterestRate }
  }

  public func createCard(name: String, type: CardType, rate: Double?, cutDay: Int, payDay: Int) async throws {
    if let demo { return await demo.createCard(name: name, type: type, rate: rate, cutDay: cutDay, payDay: payDay) }
    try await client.from("wallet_cards")
      .insert(
        CardRow(
          userId: requireUser(), name: name, type: type.rawValue, cutDay: cutDay, payDay: payDay,
          nominalInterestRate: rate)
      ).execute()
  }

  public func updateCard(id: String, name: String, type: CardType, rate: Double?, cutDay: Int, payDay: Int)
    async throws
  {
    if let demo {
      return await demo.updateCard(id: id, name: name, type: type, rate: rate, cutDay: cutDay, payDay: payDay)
    }
    try await client.from("wallet_cards")
      .update(CardRow(name: name, type: type.rawValue, cutDay: cutDay, payDay: payDay, nominalInterestRate: rate))
      .eq("id", value: id).execute()
  }

  public func deleteCard(id: String) async throws {
    if let demo { return try await demo.deleteCard(id: id) }
    try await softDelete("soft_delete_wallet_card", id: id)
  }

  // MARK: Categories & tags

  public func categories() async throws -> Served<[WalletCore.Category]> {
    if let demo { return Served(await demo.listCategories(), fromCache: false) }
    return try await cached(CacheKey.categories) {
      try await client.from("wallet_categories").select().is("deletedAt", value: nil).order("createdAt")
        .execute().value
    }
  }

  struct NamedRow: Encodable {
    var userId: String?
    var name: String
    var description: String?
    var hidden: Bool?
    var writeNullDescription = false

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encodeIfPresent(userId, forKey: .userId)
      try c.encode(name, forKey: .name)
      if writeNullDescription { try c.encode(description, forKey: .description) } else {
        try c.encodeIfPresent(description, forKey: .description)
      }
      try c.encodeIfPresent(hidden, forKey: .hidden)
    }
    enum CodingKeys: String, CodingKey { case userId, name, description, hidden }
  }

  @discardableResult
  public func createCategory(name: String, description: String? = nil) async throws -> WalletCore.Category {
    if let demo { return await demo.createCategory(name: name, description: description) }
    return try await client.from("wallet_categories")
      .insert(NamedRow(userId: requireUser(), name: name, description: description))
      .select().single().execute().value
  }

  public func updateCategory(id: String, name: String, description: String?) async throws {
    if let demo { return await demo.updateCategory(id: id, name: name, description: description) }
    try await client.from("wallet_categories")
      .update(NamedRow(name: name, description: description, writeNullDescription: true))
      .eq("id", value: id).execute()
  }

  public func deleteCategory(id: String) async throws {
    if let demo { return try await demo.deleteCategory(id: id) }
    try await softDelete("soft_delete_wallet_category", id: id)
  }

  public func tags() async throws -> Served<[Tag]> {
    if let demo { return Served(await demo.listTags(), fromCache: false) }
    return try await cached(CacheKey.tags) {
      try await client.from("wallet_tags").select().is("deletedAt", value: nil).order("createdAt").execute().value
    }
  }

  @discardableResult
  public func createTag(name: String, description: String? = nil) async throws -> Tag {
    if let demo { return await demo.createTag(name: name, description: description) }
    return try await client.from("wallet_tags")
      .insert(NamedRow(userId: requireUser(), name: name, description: description))
      .select().single().execute().value
  }

  public func updateTag(id: String, name: String, description: String?, hidden: Bool) async throws {
    if let demo { return await demo.updateTag(id: id, name: name, description: description, hidden: hidden) }
    try await client.from("wallet_tags")
      .update(NamedRow(name: name, description: description, hidden: hidden, writeNullDescription: true))
      .eq("id", value: id).execute()
  }

  public func deleteTag(id: String) async throws {
    if let demo { return try await demo.deleteTag(id: id) }
    try await softDelete("soft_delete_wallet_tag", id: id)
  }

  // MARK: Assets

  public func assets() async throws -> Served<[Asset]> {
    if let demo { return Served(await demo.listAssets(), fromCache: false) }
    return try await cached(CacheKey.assets) {
      try await client.from("wallet_assets").select().is("deletedAt", value: nil)
        .order("boughtAt", ascending: false).execute().value
    }
  }

  struct AssetRow: Encodable {
    var userId: String?
    var name: String
    var provider: String
    var value: Double
    var boughtAt: Date
    var endedAt: Date?
    var soldValue: Double?

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encodeIfPresent(userId, forKey: .userId)
      try c.encode(name, forKey: .name)
      try c.encode(provider, forKey: .provider)
      try c.encode(value, forKey: .value)
      try c.encode(boughtAt, forKey: .boughtAt)
      try c.encode(endedAt, forKey: .endedAt)
      try c.encode(soldValue, forKey: .soldValue)
    }
    enum CodingKeys: String, CodingKey { case userId, name, provider, value, boughtAt, endedAt, soldValue }
  }

  public func saveAsset(
    id: String?, name: String, provider: String, value: Double, boughtAt: Date, endedAt: Date?, soldValue: Double?
  ) async throws {
    if let demo {
      return await demo.saveAsset(
        id: id, name: name, provider: provider, value: value, boughtAt: boughtAt, endedAt: endedAt, soldValue: soldValue)
    }
    if let id {
      try await client.from("wallet_assets")
        .update(
          AssetRow(name: name, provider: provider, value: value, boughtAt: boughtAt, endedAt: endedAt, soldValue: soldValue)
        )
        .eq("id", value: id).execute()
    } else {
      try await client.from("wallet_assets")
        .insert(
          AssetRow(
            userId: requireUser(), name: name, provider: provider, value: value, boughtAt: boughtAt, endedAt: endedAt,
            soldValue: soldValue)
        ).execute()
    }
  }

  public func deleteAsset(id: String) async throws {
    if let demo { return try await demo.deleteAsset(id: id) }
    try await softDelete("soft_delete_wallet_asset", id: id)
  }

  // MARK: Loans

  public func loans() async throws -> Served<[Loan]> {
    if let demo { return Served(await demo.listLoans(), fromCache: false) }
    return try await cached(CacheKey.loans) {
      try await client.from("wallet_loans").select().is("deletedAt", value: nil).order("createdAt").execute().value
    }
  }

  struct LoanRow: Encodable {
    var userId: String?
    var accountId: String
    var name: String
    var value: Double
    var nominalInterestRate: Double?
    var termMonths: Int
    var paymentDay: Int
    var firstPaymentDate: String

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encodeIfPresent(userId, forKey: .userId)
      try c.encode(accountId, forKey: .accountId)
      try c.encode(name, forKey: .name)
      try c.encode(value, forKey: .value)
      try c.encode(nominalInterestRate, forKey: .nominalInterestRate)
      try c.encode(termMonths, forKey: .termMonths)
      try c.encode(paymentDay, forKey: .paymentDay)
      try c.encode(firstPaymentDate, forKey: .firstPaymentDate)
    }
    enum CodingKeys: String, CodingKey {
      case userId, accountId, name, value, nominalInterestRate, termMonths, paymentDay, firstPaymentDate
    }
  }

  public func saveLoan(
    id: String?, accountId: String, name: String, value: Double, rate: Double?, termMonths: Int, paymentDay: Int,
    firstPaymentDate: Date
  ) async throws {
    if let demo {
      return await demo.saveLoan(
        id: id, accountId: accountId, name: name, value: value, rate: rate, termMonths: termMonths,
        paymentDay: paymentDay, firstPaymentDate: firstPaymentDate)
    }
    var row = LoanRow(
      accountId: accountId, name: name, value: value, nominalInterestRate: rate, termMonths: termMonths,
      paymentDay: paymentDay, firstPaymentDate: LocalDay.format(firstPaymentDate))
    if let id {
      try await client.from("wallet_loans").update(row).eq("id", value: id).execute()
    } else {
      row.userId = try requireUser()
      try await client.from("wallet_loans").insert(row).execute()
    }
  }

  public func deleteLoan(id: String) async throws {
    if let demo { return try await demo.deleteLoan(id: id) }
    try await softDelete("soft_delete_wallet_loan", id: id)
  }

  public func capitalPayments() async throws -> Served<[LoanCapitalPayment]> {
    if let demo { return Served(await demo.listCapitalPayments(), fromCache: false) }
    return try await cached(CacheKey.loanCapitalPayments) {
      try await client.from("wallet_loan_capital_payments").select().is("deletedAt", value: nil).order("paidAt")
        .execute().value
    }
  }

  public func createCapitalPayment(loanId: String, value: Double, paidAt: Date) async throws {
    if let demo { return await demo.createCapitalPayment(loanId: loanId, value: value, paidAt: paidAt) }
    struct Row: Encodable { var userId: String, loanId: String, value: Double, paidAt: String }
    try await client.from("wallet_loan_capital_payments")
      .insert(Row(userId: requireUser(), loanId: loanId, value: value, paidAt: LocalDay.format(paidAt))).execute()
  }

  public func deleteCapitalPayment(id: String) async throws {
    if let demo { return try await demo.deleteCapitalPayment(id: id) }
    try await softDelete("soft_delete_wallet_loan_capital_payment", id: id)
  }

  // MARK: Recurring movements

  static let recurringSelect = "*, wallet_categories(name), wallet_tags(name)"

  public func recurringMovements() async throws -> Served<[RecurringMovement]> {
    if let demo { return Served(await demo.listRecurring(), fromCache: false) }
    return try await cached(CacheKey.recurringMovements) {
      try await client.from("wallet_recurring_movements").select(Self.recurringSelect).is("deletedAt", value: nil)
        .order("createdAt").execute().value
    }
  }

  struct RecurringRow: Encodable {
    var userId: String?
    var name: String
    var description: String?
    var value: Double
    var categoryId: String
    var tagId: String
    var yearlyPayment: Bool

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encodeIfPresent(userId, forKey: .userId)
      try c.encode(name, forKey: .name)
      try c.encode(description, forKey: .description)
      try c.encode(value, forKey: .value)
      try c.encode(categoryId, forKey: .categoryId)
      try c.encode(tagId, forKey: .tagId)
      try c.encode(yearlyPayment, forKey: .yearlyPayment)
    }
    enum CodingKeys: String, CodingKey { case userId, name, description, value, categoryId, tagId, yearlyPayment }
  }

  public func saveRecurringMovement(
    id: String?, name: String, description: String?, value: Double, categoryId: String, tagId: String, yearly: Bool
  ) async throws {
    if let demo {
      return await demo.saveRecurring(
        id: id, name: name, description: description, value: value, categoryId: categoryId, tagId: tagId, yearly: yearly)
    }
    var row = RecurringRow(
      name: name, description: description, value: value, categoryId: categoryId, tagId: tagId, yearlyPayment: yearly)
    if let id {
      try await client.from("wallet_recurring_movements").update(row).eq("id", value: id).execute()
    } else {
      row.userId = try requireUser()
      try await client.from("wallet_recurring_movements").insert(row).execute()
    }
  }

  public func deleteRecurringMovement(id: String) async throws {
    if let demo { return try await demo.deleteRecurring(id: id) }
    try await softDelete("soft_delete_wallet_recurring_movement", id: id)
  }

  // MARK: Transactions

  static let txSelect =
    "*, wallet_accounts(name), wallet_cards(name), wallet_categories(name), wallet_tags(name), wallet_credits(transactedAt)"

  /// Rows in [month]'s local calendar month, newest first.
  public func transactions(month: Date) async throws -> Served<[Transaction]> {
    let start = WalletCalendar.startOfMonth(month)
    let end = WalletCalendar.monthStart(month, offset: 1)
    if let demo { return Served(await demo.listTransactions(from: start, to: end), fromCache: false) }
    return try await cached(CacheKey.month(start)) {
      try await client.from("wallet_transactions").select(Self.txSelect).is("deletedAt", value: nil)
        .gte("transactedAt", value: WalletJSON.formatTimestamp(start))
        .lt("transactedAt", value: WalletJSON.formatTimestamp(end))
        .order("transactedAt", ascending: false).execute().value
    }
  }

  /// Full history through the end of [year] (cumulative charts need earlier
  /// years too). Pages past PostgREST's 1000-row cap.
  public func transactions(throughYear year: Date) async throws -> Served<[Transaction]> {
    if let demo {
      let end = WalletCalendar.date(WalletCalendar.year(year) + 1, 1)
      return Served(await demo.listTransactions(before: end), fromCache: false)
    }
    let end = WalletJSON.formatTimestamp(WalletCalendar.date(WalletCalendar.year(year) + 1, 1))
    return try await cached(CacheKey.year(year)) {
      var out: [Transaction] = []
      let page = 1000
      var from = 0
      while true {
        let rows: [Transaction] = try await client.from("wallet_transactions").select(Self.txSelect)
          .is("deletedAt", value: nil).lt("transactedAt", value: end)
          .order("transactedAt", ascending: false).range(from: from, to: from + page - 1).execute().value
        out += rows
        if rows.count < page { break }
        from += page
      }
      return out
    }
  }

  /// Rows dated in [year] only (lighter than the full history the iPhone's
  /// cumulative chart needs).
  public func transactions(inYear year: Int) async throws -> Served<[Transaction]> {
    if let demo {
      let rows = await demo.listTransactions(
        from: WalletCalendar.date(year, 1), to: WalletCalendar.date(year + 1, 1))
      return Served(rows, fromCache: false)
    }
    let start = WalletJSON.formatTimestamp(WalletCalendar.date(year, 1))
    let end = WalletJSON.formatTimestamp(WalletCalendar.date(year + 1, 1))
    return try await cached(CacheKey.yearOnly(year)) {
      var out: [Transaction] = []
      let page = 1000
      var from = 0
      while true {
        let rows: [Transaction] = try await client.from("wallet_transactions").select(Self.txSelect)
          .is("deletedAt", value: nil).gte("transactedAt", value: start).lt("transactedAt", value: end)
          .order("transactedAt", ascending: false).range(from: from, to: from + page - 1).execute().value
        out += rows
        if rows.count < page { break }
        from += page
      }
      return out
    }
  }

  /// All-time case-insensitive description search (not cached).
  public func searchTransactions(_ query: String, limit: Int = 200) async throws -> [Transaction] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }
    if let demo { return await demo.search(q, limit: limit) }
    let escaped = q.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%")
      .replacingOccurrences(of: "_", with: "\\_")
    return try await client.from("wallet_transactions").select(Self.txSelect).is("deletedAt", value: nil)
      .ilike("description", pattern: "%\(escaped)%").order("transactedAt", ascending: false).limit(limit)
      .execute().value
  }

  /// Every deferred installment (rows with a credit id).
  public func creditInstallments() async throws -> Served<[Transaction]> {
    if let demo { return Served(await demo.listCreditInstallments(), fromCache: false) }
    return try await cached(CacheKey.creditGroups) {
      try await client.from("wallet_transactions").select(Self.txSelect).not("creditId", operator: .is, value: "null")
        .is("deletedAt", value: nil).order("transactedAt", ascending: false).execute().value
    }
  }

  public func installments(credit: String) async throws -> [Transaction] {
    guard !credit.isEmpty else { return [] }
    if let demo { return await demo.installments(credit: credit) }
    return try await cached(CacheKey.credit(credit)) {
      try await client.from("wallet_transactions").select(Self.txSelect).eq("creditId", value: credit)
        .is("deletedAt", value: nil).order("transactedAt", ascending: true).execute().value
    }.value
  }

  public struct TransactionDraft: Sendable {
    public var accountId: String?
    public var cardId: String?
    public var categoryId: String?
    public var tagId: String?
    public var description: String?
    public var transactedAt: Date
    public var value: Double
    public var ignore: Bool
    public var percentage: Double
    public var transferGroupId: String?
    public var creditId: String?

    public init(
      accountId: String? = nil, cardId: String? = nil, categoryId: String? = nil, tagId: String? = nil,
      description: String? = nil, transactedAt: Date, value: Double, ignore: Bool = false, percentage: Double = 100,
      transferGroupId: String? = nil, creditId: String? = nil
    ) {
      self.accountId = accountId
      self.cardId = cardId
      self.categoryId = categoryId
      self.tagId = tagId
      self.description = description
      self.transactedAt = transactedAt
      self.value = value
      self.ignore = ignore
      self.percentage = percentage
      self.transferGroupId = transferGroupId
      self.creditId = creditId
    }
  }

  /// Insert omits nil fields; update writes them as null (to clear relations).
  private struct TxRow: Encodable {
    var draft: TransactionDraft
    var userId: String?

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      let isInsert = userId != nil
      func put(_ v: String?, _ k: CodingKeys) throws {
        if isInsert { try c.encodeIfPresent(v, forKey: k) } else { try c.encode(v, forKey: k) }
      }
      try c.encodeIfPresent(userId, forKey: .userId)
      try put(draft.accountId, .accountId)
      try put(draft.cardId, .cardId)
      try put(draft.categoryId, .categoryId)
      try put(draft.tagId, .tagId)
      try put(draft.description, .description)
      try put(draft.transferGroupId, .transferGroupId)
      try put(draft.creditId, .creditId)
      try c.encode(draft.transactedAt, forKey: .transactedAt)
      try c.encode(draft.value, forKey: .value)
      try c.encode(draft.ignore, forKey: .ignore)
      try c.encode(draft.percentage, forKey: .percentage)
    }
    enum CodingKeys: String, CodingKey {
      case userId, accountId, cardId, categoryId, tagId, description, transactedAt, value, ignore, percentage
      case transferGroupId, creditId
    }
  }

  public func createTransaction(_ d: TransactionDraft) async throws {
    if let demo { return await demo.createTransaction(d) }
    try await client.from("wallet_transactions").insert(TxRow(draft: d, userId: requireUser())).execute()
  }

  public func updateTransaction(id: String, _ d: TransactionDraft) async throws {
    if let demo { return await demo.updateTransaction(id: id, d) }
    try await client.from("wallet_transactions").update(TxRow(draft: d, userId: nil)).eq("id", value: id).execute()
  }

  public func deleteTransaction(id: String) async throws {
    if let demo { return try await demo.deleteTransaction(id: id) }
    try await softDelete("soft_delete_wallet_transaction", id: id)
  }

  // MARK: Wallet credits

  static let creditSelect = "id,userId,transactedAt,graceMonths,termMonths,description,createdAt,updatedAt,deletedAt"

  public func insertCredit(transactedAt: Date, graceMonths: Int, termMonths: Int, description: String?) async throws
    -> WalletCredit
  {
    if let demo {
      return await demo.insertCredit(
        transactedAt: transactedAt, graceMonths: graceMonths, termMonths: termMonths, description: description)
    }
    struct Row: Encodable {
      var userId: String, transactedAt: Date, graceMonths: Int, termMonths: Int, description: String?
    }
    let note = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    return try await client.from("wallet_credits")
      .insert(
        Row(
          userId: requireUser(), transactedAt: transactedAt, graceMonths: graceMonths, termMonths: termMonths,
          description: (note ?? "").isEmpty ? nil : note)
      )
      .select(Self.creditSelect).single().execute().value
  }

  public func credit(id: String) async throws -> WalletCredit? {
    guard !id.isEmpty else { return nil }
    if let demo { return await demo.credit(id: id) }
    return try await readThroughItem(user: userId, key: CacheKey.walletCredit(id), cache: cache) {
      let rows: [WalletCredit] = try await client.from("wallet_credits").select(Self.creditSelect).eq("id", value: id)
        .limit(1).execute().value
      return rows.first
    }.value
  }

  public func updateCredit(id: String, graceMonths: Int, termMonths: Int, transactedAt: Date?) async throws {
    if let demo {
      return await demo.updateCredit(id: id, graceMonths: graceMonths, termMonths: termMonths, transactedAt: transactedAt)
    }
    struct Row: Encodable { var graceMonths: Int, termMonths: Int, transactedAt: Date? }
    try await client.from("wallet_credits")
      .update(Row(graceMonths: graceMonths, termMonths: termMonths, transactedAt: transactedAt))
      .eq("id", value: id).execute()
  }
}
