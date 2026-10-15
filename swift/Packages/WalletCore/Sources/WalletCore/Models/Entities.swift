import Foundation

// Rows of the `wallet_*` tables and views. Coding keys match the Supabase
// columns, and `encode` writes the same shape back so the offline cache can
// round-trip a row exactly as the server sent it.

public struct Account: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  public var createdAt: Date
  public var updatedAt: Date
  /// Sum of transaction `value` amounts (full amounts, not weighted).
  /// From `wallet_accounts_with_balance`.
  public var balance: Double

  public init(id: String, userId: String, name: String, createdAt: Date, updatedAt: Date, balance: Double = 0) {
    self.id = id
    self.userId = userId
    self.name = name
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.balance = balance
  }

  enum CodingKeys: String, CodingKey { case id, userId, name, createdAt, updatedAt, balance }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    balance = try c.flexibleDoubleIfPresent(.balance) ?? 0
  }
}

/// Card network, stored in `wallet_cards.type`.
public enum CardType: String, Codable, CaseIterable, Sendable {
  case visa, mastercard, diners, discover, amex, other
}

public struct Card: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  /// Nil only for cards created before types existed.
  public var type: CardType?
  public var createdAt: Date
  public var updatedAt: Date
  /// Day of month (1–30) of the statement cut.
  public var cutDay: Int
  /// Day of month (1–30) payment is due.
  public var payDay: Int
  /// Nominal annual rate as a percentage (16.5 = 16.5%).
  public var nominalInterestRate: Double?
  /// Sum of `value` for this card's rows with no `creditId`. From `wallet_cards_with_balance`.
  public var balance: Double

  public init(
    id: String, userId: String, name: String, type: CardType? = nil, createdAt: Date, updatedAt: Date,
    cutDay: Int = 24, payDay: Int = 24, nominalInterestRate: Double? = nil, balance: Double = 0
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.type = type
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.cutDay = cutDay
    self.payDay = payDay
    self.nominalInterestRate = nominalInterestRate
    self.balance = balance
  }

  enum CodingKeys: String, CodingKey {
    case id, userId, name, type, createdAt, updatedAt, cutDay, payDay, nominalInterestRate, balance
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    type = (try? c.decodeIfPresent(String.self, forKey: .type)).flatMap { $0.flatMap(CardType.init(rawValue:)) }
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    cutDay = try c.decodeIfPresent(Int.self, forKey: .cutDay) ?? 24
    payDay = try c.decodeIfPresent(Int.self, forKey: .payDay) ?? 24
    nominalInterestRate = try c.flexibleDoubleIfPresent(.nominalInterestRate)
    balance = try c.flexibleDoubleIfPresent(.balance) ?? 0
  }
}

public struct Category: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  public var description: String?
  public var createdAt: Date
  public var updatedAt: Date

  public init(id: String, userId: String, name: String, description: String? = nil, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.userId = userId
    self.name = name
    self.description = description
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct Tag: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  public var description: String?
  /// Hidden tags are left out of the transaction tag picker.
  public var hidden: Bool
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, userId: String, name: String, description: String? = nil, hidden: Bool = false,
    createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.description = description
    self.hidden = hidden
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey { case id, userId, name, description, hidden, createdAt, updatedAt }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }
}

public struct Asset: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  public var provider: String
  public var value: Double
  public var boughtAt: Date
  public var endedAt: Date?
  public var soldValue: Double?
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, userId: String, name: String, provider: String, value: Double, boughtAt: Date,
    endedAt: Date? = nil, soldValue: Double? = nil, createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.provider = provider
    self.value = value
    self.boughtAt = boughtAt
    self.endedAt = endedAt
    self.soldValue = soldValue
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Sold or closed: shown muted in the list.
  public var isEnded: Bool { endedAt != nil || soldValue != nil }

  enum CodingKeys: String, CodingKey {
    case id, userId, name, provider, value, boughtAt, endedAt, soldValue, createdAt, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
    value = try c.flexibleDoubleIfPresent(.value) ?? 0
    boughtAt = try c.decode(Date.self, forKey: .boughtAt)
    endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
    soldValue = try c.flexibleDoubleIfPresent(.soldValue)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }
}

public struct Loan: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  /// Account installments are paid from.
  public var accountId: String
  public var name: String
  /// Amount borrowed.
  public var value: Double
  /// Nominal annual rate as a percentage (16.5 = 16.5%).
  public var nominalInterestRate: Double?
  public var termMonths: Int
  /// Day of month (1–30) installments are due.
  public var paymentDay: Int
  /// Due date of the first installment (local date).
  @LocalDate public var firstPaymentDate: Date
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, userId: String, accountId: String, name: String, value: Double,
    nominalInterestRate: Double? = nil, termMonths: Int, paymentDay: Int, firstPaymentDate: Date,
    createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.accountId = accountId
    self.name = name
    self.value = value
    self.nominalInterestRate = nominalInterestRate
    self.termMonths = termMonths
    self.paymentDay = paymentDay
    self._firstPaymentDate = LocalDate(wrappedValue: firstPaymentDate)
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case id, userId, accountId, name, value, nominalInterestRate, termMonths, paymentDay
    case firstPaymentDate, createdAt, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    accountId = try c.decode(String.self, forKey: .accountId)
    name = try c.decode(String.self, forKey: .name)
    value = try c.flexibleDouble(.value)
    nominalInterestRate = try c.flexibleDoubleIfPresent(.nominalInterestRate)
    termMonths = try c.decode(Int.self, forKey: .termMonths)
    paymentDay = try c.decode(Int.self, forKey: .paymentDay)
    _firstPaymentDate = try c.decode(LocalDate.self, forKey: .firstPaymentDate)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }
}

/// Extra payment straight to a loan's principal, outside the installments.
public struct LoanCapitalPayment: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var loanId: String
  public var value: Double
  /// Day it was paid (local date).
  @LocalDate public var paidAt: Date
  public var createdAt: Date

  public init(id: String, userId: String, loanId: String, value: Double, paidAt: Date, createdAt: Date) {
    self.id = id
    self.userId = userId
    self.loanId = loanId
    self.value = value
    self._paidAt = LocalDate(wrappedValue: paidAt)
    self.createdAt = createdAt
  }

  enum CodingKeys: String, CodingKey { case id, userId, loanId, value, paidAt, createdAt }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    loanId = try c.decode(String.self, forKey: .loanId)
    value = try c.flexibleDouble(.value)
    _paidAt = try c.decode(LocalDate.self, forKey: .paidAt)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
  }
}

/// Expected recurring income (positive) or outcome (negative).
public struct RecurringMovement: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var name: String
  public var description: String?
  public var value: Double
  public var categoryId: String?
  public var tagId: String?
  public var categoryName: String?
  public var tagName: String?
  /// [value] is the full annual amount; lists and estimates use one twelfth.
  public var yearlyPayment: Bool
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, userId: String, name: String, description: String? = nil, value: Double,
    categoryId: String? = nil, tagId: String? = nil, categoryName: String? = nil, tagName: String? = nil,
    yearlyPayment: Bool = false, createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.name = name
    self.description = description
    self.value = value
    self.categoryId = categoryId
    self.tagId = tagId
    self.categoryName = categoryName
    self.tagName = tagName
    self.yearlyPayment = yearlyPayment
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Amount counted each month.
  public var monthlyAmount: Double { yearlyPayment ? value / 12 : value }

  enum CodingKeys: String, CodingKey {
    case id, userId, name, description, value, categoryId, tagId, yearlyPayment, createdAt, updatedAt
    case categories = "wallet_categories"
    case tags = "wallet_tags"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    name = try c.decode(String.self, forKey: .name)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    value = try c.flexibleDouble(.value)
    categoryId = try c.decodeIfPresent(String.self, forKey: .categoryId)
    tagId = try c.decodeIfPresent(String.self, forKey: .tagId)
    categoryName = c.embeddedName(.categories)
    tagName = c.embeddedName(.tags)
    yearlyPayment = try c.decodeIfPresent(Bool.self, forKey: .yearlyPayment) ?? false
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encode(name, forKey: .name)
    try c.encodeIfPresent(description, forKey: .description)
    try c.encode(value, forKey: .value)
    try c.encodeIfPresent(categoryId, forKey: .categoryId)
    try c.encodeIfPresent(tagId, forKey: .tagId)
    try c.encode(yearlyPayment, forKey: .yearlyPayment)
    try c.encode(createdAt, forKey: .createdAt)
    try c.encode(updatedAt, forKey: .updatedAt)
    if let categoryName { try c.encode(EmbeddedName(name: categoryName), forKey: .categories) }
    if let tagName { try c.encode(EmbeddedName(name: tagName), forKey: .tags) }
  }
}

/// Header row of a deferred card purchase; its installments share `creditId`.
public struct WalletCredit: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var transactedAt: Date
  public var graceMonths: Int
  public var termMonths: Int
  public var description: String?
  public var createdAt: Date
  public var updatedAt: Date
  public var deletedAt: Date?

  public init(
    id: String, userId: String, transactedAt: Date, graceMonths: Int, termMonths: Int,
    description: String? = nil, createdAt: Date, updatedAt: Date, deletedAt: Date? = nil
  ) {
    self.id = id
    self.userId = userId
    self.transactedAt = transactedAt
    self.graceMonths = graceMonths
    self.termMonths = termMonths
    self.description = description
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
  }
}

public struct Transaction: Codable, Identifiable, Hashable, Sendable {
  public var id: String
  public var userId: String
  public var accountId: String?
  public var cardId: String?
  public var categoryId: String?
  public var tagId: String?
  public var accountName: String?
  public var cardName: String?
  public var categoryName: String?
  public var tagName: String?
  public var description: String?
  public var transactedAt: Date
  public var value: Double
  public var ignore: Bool
  public var percentage: Double
  /// Shared by the two legs of a transfer.
  public var transferGroupId: String?
  /// Links a deferred installment to its `wallet_credits` row.
  public var creditId: String?
  /// `wallet_credits.transactedAt` (the purchase), when embedded.
  public var creditTransactedAt: Date?
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String, userId: String, accountId: String? = nil, cardId: String? = nil, categoryId: String? = nil,
    tagId: String? = nil, accountName: String? = nil, cardName: String? = nil, categoryName: String? = nil,
    tagName: String? = nil, description: String? = nil, transactedAt: Date, value: Double,
    ignore: Bool = false, percentage: Double = 100, transferGroupId: String? = nil, creditId: String? = nil,
    creditTransactedAt: Date? = nil, createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.userId = userId
    self.accountId = accountId
    self.cardId = cardId
    self.categoryId = categoryId
    self.tagId = tagId
    self.accountName = accountName
    self.cardName = cardName
    self.categoryName = categoryName
    self.tagName = tagName
    self.description = description
    self.transactedAt = transactedAt
    self.value = value
    self.ignore = ignore
    self.percentage = percentage
    self.transferGroupId = transferGroupId
    self.creditId = creditId
    self.creditTransactedAt = creditTransactedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// `value × percentage / 100`.
  public var weightedValue: Double { value * percentage / 100 }

  public func amount(weighted: Bool) -> Double { weighted ? weightedValue : value }

  /// Part of an account/card transfer (paired legs share `transferGroupId`).
  public var isTransferLeg: Bool { !(transferGroupId ?? "").isEmpty }

  /// Groups sibling installments of one deferred purchase.
  public var creditKey: String? { (creditId ?? "").isEmpty ? nil : creditId }

  public var isCreditInstallment: Bool { creditKey != nil }

  /// Category · account · card · tag, for row subtitles.
  public var relationNames: [String] {
    [categoryName, accountName, cardName, tagName].compactMap { $0 }.filter { !$0.isEmpty }
  }

  /// Account or card name of this leg.
  public var paymentMethodName: String? { accountName ?? cardName }

  enum CodingKeys: String, CodingKey {
    case id, userId, accountId, cardId, categoryId, tagId, description, transactedAt, value, ignore
    case percentage, transferGroupId, creditId, createdAt, updatedAt
    case accounts = "wallet_accounts"
    case cards = "wallet_cards"
    case categories = "wallet_categories"
    case tags = "wallet_tags"
    case credits = "wallet_credits"
  }

  private struct EmbeddedCredit: Codable { var transactedAt: Date? }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    userId = try c.decode(String.self, forKey: .userId)
    accountId = try c.decodeIfPresent(String.self, forKey: .accountId)
    cardId = try c.decodeIfPresent(String.self, forKey: .cardId)
    categoryId = try c.decodeIfPresent(String.self, forKey: .categoryId)
    tagId = try c.decodeIfPresent(String.self, forKey: .tagId)
    accountName = c.embeddedName(.accounts)
    cardName = c.embeddedName(.cards)
    categoryName = c.embeddedName(.categories)
    tagName = c.embeddedName(.tags)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    transactedAt = try c.decode(Date.self, forKey: .transactedAt)
    value = try c.flexibleDouble(.value)
    ignore = try c.decodeIfPresent(Bool.self, forKey: .ignore) ?? false
    percentage = try c.flexibleDoubleIfPresent(.percentage) ?? 100
    transferGroupId = try c.decodeIfPresent(String.self, forKey: .transferGroupId)
    creditId = try c.decodeIfPresent(String.self, forKey: .creditId)
    if let one = try? c.decodeIfPresent(EmbeddedCredit.self, forKey: .credits) {
      creditTransactedAt = one.transactedAt
    } else if let many = try? c.decodeIfPresent([EmbeddedCredit].self, forKey: .credits) {
      creditTransactedAt = many.first?.transactedAt
    } else {
      creditTransactedAt = nil
    }
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(userId, forKey: .userId)
    try c.encodeIfPresent(accountId, forKey: .accountId)
    try c.encodeIfPresent(cardId, forKey: .cardId)
    try c.encodeIfPresent(categoryId, forKey: .categoryId)
    try c.encodeIfPresent(tagId, forKey: .tagId)
    try c.encodeIfPresent(description, forKey: .description)
    try c.encode(transactedAt, forKey: .transactedAt)
    try c.encode(value, forKey: .value)
    try c.encode(ignore, forKey: .ignore)
    try c.encode(percentage, forKey: .percentage)
    try c.encodeIfPresent(transferGroupId, forKey: .transferGroupId)
    try c.encodeIfPresent(creditId, forKey: .creditId)
    try c.encode(createdAt, forKey: .createdAt)
    try c.encode(updatedAt, forKey: .updatedAt)
    if let accountName { try c.encode(EmbeddedName(name: accountName), forKey: .accounts) }
    if let cardName { try c.encode(EmbeddedName(name: cardName), forKey: .cards) }
    if let categoryName { try c.encode(EmbeddedName(name: categoryName), forKey: .categories) }
    if let tagName { try c.encode(EmbeddedName(name: tagName), forKey: .tags) }
    if let creditTransactedAt { try c.encode(EmbeddedCredit(transactedAt: creditTransactedAt), forKey: .credits) }
  }
}
