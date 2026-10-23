import Foundation

/// Builds the fake ledger shown in demo mode.
///
/// Everything is generated at the moment demo starts and is relative to [now]:
/// 13 full months of history plus the current one, deferred card purchases
/// (finished, ongoing and just started), two loans with extra payments,
/// recurring movements and assets. Amounts are randomized; the same [seed]
/// and [now] always give the same data.
public enum DemoDataGenerator {
  /// Stands in for the signed-in user's id on every demo row.
  public static let userId = "00000000-0000-4000-8000-00000000d3e0"
  public static let email = "demo@wallet.app"

  /// Name of the category and tag the app creates for balance adjustments.
  public static let adjustmentLabel = "Adjustment"

  /// Full months before the current one that get transactions.
  public static let historyMonths = 13

  public static func make(now: Date = .now, seed: UInt64? = nil) -> DemoDataSet {
    var builder = DemoBuilder(now: now, rng: DemoRandom(seed: seed ?? UInt64.random(in: 0...UInt64.max)))
    return builder.build()
  }
}

/// An account or a card, so a transfer can name either end.
private enum Place {
  case account(Account)
  case card(Card)

  var account: Account? { if case .account(let a) = self { a } else { nil } }
  var card: Card? { if case .card(let c) = self { c } else { nil } }
}

private struct DemoBuilder {
  let now: Date
  var rng: DemoRandom
  let user = DemoDataGenerator.userId
  /// When the oldest data was "created".
  let origin: Date

  var accounts: [Account] = []
  var cards: [Card] = []
  var categories: [String: Category] = [:]
  var tags: [String: Tag] = [:]
  var credits: [WalletCredit] = []
  var transactions: [Transaction] = []

  init(now: Date, rng: DemoRandom) {
    self.now = now
    self.rng = rng
    origin = WalletCalendar.monthStart(now, offset: -DemoDataGenerator.historyMonths)
  }

  // MARK: Building blocks

  mutating func id() -> String { rng.uuid() }

  /// Day [d] of [month] at [hour]:[minute], clamped to the month's length.
  func day(_ month: Date, _ d: Int, hour: Int = 12, minute: Int = 0) -> Date {
    let y = WalletCalendar.year(month), m = WalletCalendar.month(month)
    let last = WalletCalendar.daysInMonth(year: y, month: m)
    return WalletCalendar.date(y, m, min(max(d, 1), last), hour: hour, minute: minute)
  }

  mutating func account(_ name: String) -> Account {
    let a = Account(id: id(), userId: user, name: name, createdAt: origin, updatedAt: origin)
    accounts.append(a)
    return a
  }

  mutating func card(_ name: String, _ type: CardType, cut: Int, pay: Int, rate: Double) -> Card {
    let c = Card(
      id: id(), userId: user, name: name, type: type, createdAt: origin, updatedAt: origin, cutDay: cut, payDay: pay,
      nominalInterestRate: rate)
    cards.append(c)
    return c
  }

  mutating func category(_ name: String, _ description: String? = nil) {
    categories[name] = Category(
      id: id(), userId: user, name: name, description: description, createdAt: origin, updatedAt: origin)
  }

  mutating func tag(_ name: String, _ description: String? = nil, hidden: Bool = false) {
    tags[name] = Tag(
      id: id(), userId: user, name: name, description: description, hidden: hidden, createdAt: origin,
      updatedAt: origin)
  }

  /// Adds a row dated [when]. Rows after [now] are skipped unless [allowFuture]
  /// (deferred installments are the only ones dated ahead).
  @discardableResult
  mutating func add(
    at when: Date, _ value: Double, _ description: String, account: Account? = nil, card: Card? = nil,
    category: String? = nil, tag: String? = nil, ignore: Bool = false, percentage: Double = 100,
    transferGroupId: String? = nil, credit: WalletCredit? = nil, allowFuture: Bool = false
  ) -> Transaction? {
    guard allowFuture || when <= now else { return nil }
    let c = category.flatMap { categories[$0] }
    let t = tag.flatMap { tags[$0] }
    let created = credit?.createdAt ?? when
    let tx = Transaction(
      id: id(), userId: user, accountId: account?.id, cardId: card?.id, categoryId: c?.id, tagId: t?.id,
      accountName: account?.name, cardName: card?.name, categoryName: c?.name, tagName: t?.name,
      description: description, transactedAt: when, value: value, ignore: ignore, percentage: percentage,
      transferGroupId: transferGroupId, creditId: credit?.id, creditTransactedAt: credit?.transactedAt,
      createdAt: created, updatedAt: created)
    transactions.append(tx)
    return tx
  }

  /// Outflow on [from], inflow on [to]; both legs share a transfer group.
  mutating func transfer(at when: Date, _ amount: Double, from: Place, to: Place) {
    guard when <= now else { return }
    let group = id()
    add(at: when, -amount, "Transfer", account: from.account, card: from.card, transferGroupId: group)
    add(at: when, amount, "Transfer", account: to.account, card: to.card, transferGroupId: group)
  }

  // MARK: Build

  mutating func build() -> DemoDataSet {
    let checking = account("Checking")
    let savings = account("Savings")
    let cash = account("Cash")

    let visa = card("Visa Platinum", .visa, cut: 20, pay: 8, rate: 24.5)
    let mastercard = card("Mastercard Gold", .mastercard, cut: 27, pay: 15, rate: 29.9)

    let categoryList: [(String, String?)] = [
      ("Salary", "Income and bonuses"), ("Housing", nil), ("Utilities", nil), ("Groceries", nil), ("Dining", nil),
      ("Transport", nil), ("Health", nil), ("Shopping", nil), ("Entertainment", nil), ("Subscriptions", nil),
      ("Travel", nil), ("Loans", "Installments and extra payments"), ("Interest", nil),
      (DemoDataGenerator.adjustmentLabel, "Balance corrections"),
    ]
    for (name, note) in categoryList { category(name, note) }
    let tagList: [(String, String?, Bool)] = [
      ("Essential", "Needs", false), ("Leisure", "Wants", false), ("Family", nil, false), ("Work", nil, false),
      ("Monthly", "Repeats every month", false), ("Shared", "Split with someone else", false),
      (DemoDataGenerator.adjustmentLabel, nil, false), ("Archived", "Hidden from the tag picker", true),
    ]
    for (name, note, hidden) in tagList { tag(name, note, hidden: hidden) }

    let loans = makeLoans(account: checking)
    let capital = makeCapitalPayments(loans)
    makeCredits(visa: visa, mastercard: mastercard)

    for offset in -DemoDataGenerator.historyMonths...0 {
      let m = WalletCalendar.monthStart(now, offset: offset)
      if offset == -DemoDataGenerator.historyMonths { openingBalances(m, checking: checking, savings: savings, cash: cash) }
      income(m, checking: checking, savings: savings)
      fixedBills(m, checking: checking, visa: visa)
      spending(m, checking: checking, cash: cash, visa: visa, mastercard: mastercard)
      transfer(at: day(m, 4, hour: 10), 300, from: .account(checking), to: .account(savings))
      transfer(at: day(m, 6, hour: 18), 100, from: .account(checking), to: .account(cash))
      loanPayments(m, loans: loans, capital: capital, from: checking)
      if offset > -DemoDataGenerator.historyMonths { payCards(m, from: checking, cards: [visa, mastercard]) }
    }

    return DemoDataSet(
      accounts: DemoBalances.accounts(accounts, transactions),
      cards: DemoBalances.cards(cards, transactions),
      categories: categories.values.sorted { $0.name < $1.name },
      tags: tags.values.sorted { $0.name < $1.name },
      assets: makeAssets(), loans: loans, capitalPayments: capital, recurringMovements: makeRecurring(),
      credits: credits, transactions: transactions.sorted { $0.transactedAt > $1.transactedAt })
  }

  // MARK: Monthly activity

  mutating func openingBalances(_ m: Date, checking: Account, savings: Account, cash: Account) {
    let label = DemoDataGenerator.adjustmentLabel
    for (i, (account, amount)) in [(checking, 3_000.0), (savings, 9_000), (cash, 120)].enumerated() {
      add(at: day(m, 1, hour: 8, minute: i), amount, label, account: account, category: label, tag: label)
    }
  }

  mutating func income(_ m: Date, checking: Account, savings: Account) {
    add(at: day(m, 1, hour: 9), 4_200, "Salary", account: checking, category: "Salary", tag: "Monthly")
    if WalletCalendar.month(m) == 12 {
      add(at: day(m, 15, hour: 10), 1_600, "Year-end bonus", account: checking, category: "Salary", tag: "Work")
    }
    if rng.chance(0.3) {
      add(at: day(m, rng.int(8...25), hour: 16), rng.money(180...650), "Freelance project", account: checking,
        category: "Salary", tag: "Work")
    }
    add(at: day(m, 28, hour: 6), rng.money(8...14), "Savings interest", account: savings, category: "Interest")
  }

  mutating func fixedBills(_ m: Date, checking: Account, visa: Card) {
    add(at: day(m, 3, hour: 8), -950, "Rent", account: checking, category: "Housing", tag: "Essential")
    add(at: day(m, 2, hour: 7), -35, "Gym membership", account: checking, category: "Health", tag: "Monthly")
    add(at: day(m, 8, hour: 9), -rng.money(55...115), "Electricity", account: checking, category: "Utilities",
      tag: "Shared", percentage: 50)
    add(at: day(m, 9, hour: 9), -rng.money(18...32), "Water", account: checking, category: "Utilities", tag: "Essential")
    add(at: day(m, 12, hour: 9), -45.90, "Internet", account: checking, category: "Utilities", tag: "Monthly")
    add(at: day(m, 14, hour: 9), -29, "Phone plan", account: checking, category: "Utilities", tag: "Monthly")
    add(at: day(m, 5, hour: 3), -15.99, "Netflix", card: visa, category: "Subscriptions", tag: "Leisure")
    add(at: day(m, 7, hour: 3), -10.99, "Spotify", card: visa, category: "Subscriptions", tag: "Leisure")
    add(at: day(m, 10, hour: 3), -2.99, "iCloud storage", card: visa, category: "Subscriptions", tag: "Monthly")
  }

  mutating func spending(_ m: Date, checking: Account, cash: Account, visa: Card, mastercard: Card) {
    for _ in 0..<rng.int(5...8) {
      let onDebit = rng.chance(0.6)
      add(at: randomMoment(m), -rng.money(18...115),
        rng.pick(["Whole Foods", "Trader Joe's", "Lidl", "Carrefour", "Costco"]), account: onDebit ? checking : nil,
        card: onDebit ? nil : visa, category: "Groceries", tag: "Essential")
    }

    for _ in 0..<rng.int(4...7) {
      let place = rng.pick(["Pizza Place", "Sushi Bar", "Coffee shop", "Burger joint", "Brunch cafe", "Dinner with friends"])
      let shared = place == "Dinner with friends"
      add(at: randomMoment(m), -rng.money(7...62), place, card: visa, category: "Dining",
        tag: shared ? "Shared" : "Leisure", percentage: shared ? 50 : 100)
    }

    for _ in 0..<rng.int(3...5) {
      add(at: randomMoment(m), -rng.money(4...48), rng.pick(["Uber", "Gas station", "Parking", "Metro top-up"]),
        card: mastercard, category: "Transport", tag: "Essential")
    }

    if rng.chance(0.8) {
      for _ in 0..<rng.int(1...3) {
        add(at: randomMoment(m), -rng.money(9...70), rng.pick(["Cinema", "Concert tickets", "Bowling", "Video game"]),
          card: visa, category: "Entertainment", tag: "Leisure")
      }
    }
    if rng.chance(0.5) {
      let visit = rng.pick(["Pharmacy", "Dentist", "Doctor visit"])
      add(at: randomMoment(m), -(visit == "Pharmacy" ? rng.money(8...35) : rng.money(60...140)), visit,
        account: checking, category: "Health", tag: "Essential")
    }
    if rng.chance(0.6) {
      add(at: randomMoment(m), -rng.money(20...170),
        rng.pick(["Amazon order", "Clothing store", "Home decor", "Bookstore"]), card: mastercard,
        category: "Shopping", tag: "Family")
    }
    if rng.chance(0.12) {
      add(at: day(m, rng.int(3...24), hour: 15), -rng.money(180...420), "Weekend trip hotel", card: mastercard,
        category: "Travel", tag: "Leisure")
    }
    // A work lunch the employer pays back: both rows are ignored in the totals.
    if rng.chance(0.35) {
      let amount = rng.money(25...80)
      let d = rng.int(2...20)
      add(at: day(m, d, hour: 13), -amount, "Team lunch (reimbursed)", account: checking, category: "Dining",
        tag: "Work", ignore: true)
      add(at: day(m, d + 6, hour: 11), amount, "Expense reimbursement", account: checking, category: "Salary",
        tag: "Work", ignore: true)
    }
    for _ in 0..<rng.int(2...4) {
      add(at: randomMoment(m), -rng.money(3...25), rng.pick(["Street food", "Market", "Barber", "Tip"]),
        account: cash, category: "Dining", tag: "Leisure")
    }
  }

  mutating func randomMoment(_ m: Date) -> Date {
    day(m, rng.int(1...28), hour: rng.int(8...21), minute: rng.int(0...59))
  }

  /// Installments and extra payments of each loan that fall in [m].
  mutating func loanPayments(_ m: Date, loans: [Loan], capital: [LoanCapitalPayment], from account: Account) {
    for loan in loans {
      for case .installment(let i) in LoanMath.schedule(loan, capitalPayments: capital)
      where WalletCalendar.isSameMonth(i.date, m) {
        add(at: i.date.addingTimeInterval(9 * 3600), -i.payment, "\(loan.name) installment", account: account,
          category: "Loans", tag: "Monthly")
      }
      for p in capital where p.loanId == loan.id && WalletCalendar.isSameMonth(p.paidAt, m) {
        add(at: p.paidAt.addingTimeInterval(10 * 3600), -p.value, "\(loan.name) extra payment", account: account,
          category: "Loans", tag: "Work")
      }
    }
  }

  /// On a card's pay day, the previous month's spending (deferred installments
  /// included) is paid from [from]. Skipped while the pay day is still ahead,
  /// so a card can show a balance to pay.
  mutating func payCards(_ m: Date, from: Account, cards: [Card]) {
    let previous = WalletCalendar.monthStart(m, offset: -1)
    for card in cards {
      let owed = transactions.filter {
        $0.cardId == card.id && !$0.isTransferLeg && WalletCalendar.isSameMonth($0.transactedAt, previous)
      }.reduce(0) { $0 + $1.value }
      guard owed < -0.005 else { continue }
      transfer(at: day(m, card.payDay, hour: 10), Double((-owed).fixed2) ?? -owed, from: .account(from), to: .card(card))
    }
  }
}

// MARK: - Loans, deferred purchases, assets, recurring movements

extension DemoBuilder {
  /// A car loan with ten installments already paid and a shorter personal loan.
  mutating func makeLoans(account: Account) -> [Loan] {
    let car = Loan(
      id: id(), userId: user, accountId: account.id, name: "Car loan", value: 12_000, nominalInterestRate: 9.5,
      termMonths: 48, paymentDay: 15, firstPaymentDate: day(WalletCalendar.monthStart(now, offset: -10), 15),
      createdAt: origin, updatedAt: origin)
    let personal = Loan(
      id: id(), userId: user, accountId: account.id, name: "Personal loan", value: 3_000, nominalInterestRate: 7.5,
      termMonths: 18, paymentDay: 5, firstPaymentDate: day(WalletCalendar.monthStart(now, offset: -4), 5),
      createdAt: origin, updatedAt: origin)
    return [car, personal]
  }

  mutating func makeCapitalPayments(_ loans: [Loan]) -> [LoanCapitalPayment] {
    let car = day(WalletCalendar.monthStart(now, offset: -3), 20)
    let personal = day(WalletCalendar.monthStart(now, offset: -1), 18)
    return [
      LoanCapitalPayment(id: id(), userId: user, loanId: loans[0].id, value: 1_000, paidAt: car, createdAt: car),
      LoanCapitalPayment(id: id(), userId: user, loanId: loans[1].id, value: 250, paidAt: personal, createdAt: personal),
    ]
  }

  /// Deferred card purchases: a `wallet_credits` header plus one ignored
  /// installment row per month, the way the app saves them.
  mutating func makeCredits(visa: Card, mastercard: Card) {
    struct Plan {
      var name: String
      var total: Double
      var card: Card
      var monthsAgo: Int
      var day: Int
      var grace: Int
      var term: Int
      var category: String
      var tag: String
    }
    let plans = [
      Plan(name: "Laptop", total: 1_499, card: visa, monthsAgo: 5, day: 12, grace: 0, term: 6, category: "Shopping", tag: "Work"),
      Plan(name: "Sofa", total: 840, card: mastercard, monthsAgo: 4, day: 20, grace: 0, term: 12, category: "Housing", tag: "Family"),
      Plan(name: "Flights to Lisbon", total: 620, card: visa, monthsAgo: 1, day: 9, grace: 1, term: 3, category: "Travel", tag: "Leisure"),
      Plan(name: "Phone", total: 960, card: mastercard, monthsAgo: 8, day: 3, grace: 0, term: 24, category: "Shopping", tag: "Essential"),
    ]
    for plan in plans {
      let purchase = day(WalletCalendar.monthStart(now, offset: -plan.monthsAgo), plan.day, hour: 14, minute: 30)
      guard
        let schedule = try? DeferredCreditSchedule.installments(
          purchase: purchase, graceMonths: plan.grace, termMonths: plan.term, cardCutDay: plan.card.cutDay)
      else { continue }
      let header = WalletCredit(
        id: id(), userId: user, transactedAt: purchase, graceMonths: plan.grace, termMonths: plan.term,
        description: plan.name, createdAt: purchase, updatedAt: purchase)
      credits.append(header)
      let parts = splitEqualAmountParts(-plan.total, plan.term)
      for i in 0..<plan.term {
        add(at: schedule[i], parts[i], CreditDescription.prefixed(current: i + 1, total: plan.term, note: plan.name),
          card: plan.card, category: plan.category, tag: plan.tag, ignore: true, credit: header, allowFuture: true)
      }
    }
  }

  mutating func makeAssets() -> [Asset] {
    func months(_ n: Int, _ d: Int) -> Date { day(WalletCalendar.monthStart(now, offset: -n), d) }
    return [
      Asset(
        id: id(), userId: user, name: "MacBook Pro", provider: "Apple", value: 2_399, boughtAt: months(14, 10),
        createdAt: months(14, 10), updatedAt: months(14, 10)),
      Asset(
        id: id(), userId: user, name: "Index fund", provider: "Vanguard", value: 5_000, boughtAt: months(11, 2),
        createdAt: months(11, 2), updatedAt: months(11, 2)),
      Asset(
        id: id(), userId: user, name: "Road bike", provider: "Decathlon", value: 780, boughtAt: months(7, 22),
        createdAt: months(7, 22), updatedAt: months(7, 22)),
      Asset(
        id: id(), userId: user, name: "Old iPhone", provider: "Apple", value: 999, boughtAt: months(30, 5),
        endedAt: months(6, 14), soldValue: 310, createdAt: months(30, 5), updatedAt: months(6, 14)),
    ]
  }

  mutating func makeRecurring() -> [RecurringMovement] {
    func movement(_ name: String, _ value: Double, _ category: String, _ tag: String, yearly: Bool = false,
      note: String? = nil) -> RecurringMovement
    {
      let c = categories[category], t = tags[tag]
      return RecurringMovement(
        id: id(), userId: user, name: name, description: note, value: value, categoryId: c?.id, tagId: t?.id,
        categoryName: c?.name, tagName: t?.name, yearlyPayment: yearly, createdAt: origin, updatedAt: origin)
    }
    return [
      movement("Salary", 4_200, "Salary", "Monthly"),
      movement("Rent", -950, "Housing", "Essential"),
      movement("Internet", -45.90, "Utilities", "Monthly"),
      movement("Phone plan", -29, "Utilities", "Monthly"),
      movement("Gym membership", -35, "Health", "Monthly"),
      movement("Streaming", -28.97, "Subscriptions", "Leisure", note: "Netflix, Spotify and iCloud"),
      movement("Car insurance", -720, "Transport", "Essential", yearly: true, note: "Paid once a year"),
      movement("Home insurance", -240, "Housing", "Essential", yearly: true),
    ]
  }
}
