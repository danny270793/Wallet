import Foundation

extension Double {
  /// Two decimals with a dot, like Dart's `toStringAsFixed(2)`. Used for stored
  /// text (descriptions, edit fields) where locale formatting must not leak in.
  public var fixed2: String { String(format: "%.2f", self) }
}

public enum AmountInput {
  /// Parses an amount: optional leading minus, digits, optional fraction. When
  /// there is a comma but no dot, the first comma is the decimal separator.
  public static func parse(_ raw: String?) -> Double? {
    guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    if s.contains(","), !s.contains("."), let r = s.range(of: ",") {
      s.replaceSubrange(r, with: ".")
    }
    guard s.range(of: #"^-?(\d+\.?\d*|\.\d+)$"#, options: .regularExpression) != nil,
      let x = Double(s), x.isFinite
    else { return nil }
    return x
  }

  /// Keeps an optional leading minus, digits and one `.` or `,`.
  public static func filter(_ input: String, allowNegative: Bool) -> String {
    var out = ""
    var hasSeparator = false
    for (i, ch) in input.enumerated() {
      if allowNegative && ch == "-" && i == 0 {
        out.append(ch)
      } else if ch.isASCII && ch.isNumber {
        out.append(ch)
      } else if (ch == "." || ch == ","), !hasSeparator {
        out.append(ch)
        hasSeparator = true
      }
    }
    return out
  }

  /// Integer-only filter for day/month fields.
  public static func digits(_ input: String) -> String { input.filter { $0.isASCII && $0.isNumber } }
}

public enum Sorting {
  /// Case-insensitive by name.
  public static func byName<T>(_ items: [T], _ name: (T) -> String) -> [T] {
    items.sorted { name($0).lowercased() < name($1).lowercased() }
  }

  /// Visible first (A–Z), then hidden (A–Z).
  public static func visibleThenByName(_ tags: [Tag]) -> [Tag] {
    tags.sorted {
      if $0.hidden != $1.hidden { return !$0.hidden }
      return $0.name.lowercased() < $1.name.lowercased()
    }
  }
}

/// Splits [total] into [parts] equal amounts at 2 decimals; the last absorbs the remainder.
public func splitEqualAmountParts(_ total: Double, _ parts: Int) -> [Double] {
  precondition(parts > 0, "parts must be positive")
  func round2(_ v: Double) -> Double { Double(v.fixed2)! }
  if parts == 1 { return [round2(total)] }
  let step = round2(total / Double(parts))
  var out = Array(repeating: step, count: parts)
  out[parts - 1] = round2(total - step * Double(parts - 1))
  return out
}

public enum CreditDescription {
  private static let prefix = #"^\(\d+/\d+\)\s*"#

  /// Removes a leading "(n/m) " saved on installment descriptions.
  public static func strip(_ description: String?) -> String {
    let s = description ?? ""
    guard let r = s.range(of: prefix, options: .regularExpression) else { return s }
    return String(s[r.upperBound...])
  }

  /// "(current/total)" then the optional note.
  public static func prefixed(current: Int, total: Int, note: String?) -> String {
    let p = "(\(current)/\(total))"
    let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? p : "\(p) \(trimmed)"
  }
}

/// Calendar-length holding period of an asset.
public enum AssetHolding {
  public struct YMD: Hashable, Sendable {
    public var years: Int
    public var months: Int
    public var days: Int
    public var isZero: Bool { years == 0 && months == 0 && days == 0 }
  }

  /// Nil when the end date falls before the purchase.
  public static func ymd(boughtAt: Date, endedAt: Date?, now: Date = .now) -> YMD? {
    let cal = WalletCalendar.self
    let start = cal.startOfDay(boughtAt)
    let end = cal.startOfDay(endedAt ?? now)
    if end < start { return nil }
    var years = cal.year(end) - cal.year(start)
    var months = cal.month(end) - cal.month(start)
    var days = cal.day(end) - cal.day(start)
    if days < 0 {
      months -= 1
      days += cal.day(cal.date(cal.year(end), cal.month(end), 0))
    }
    if months < 0 {
      years -= 1
      months += 12
    }
    return YMD(years: years, months: months, days: days)
  }

  /// Value divided by months held (days count as a fraction of ~30.4375).
  public static func valuePerMonth(_ value: Double, boughtAt: Date, endedAt: Date?, now: Date = .now) -> Double? {
    guard let y = ymd(boughtAt: boughtAt, endedAt: endedAt, now: now), !y.isZero else { return nil }
    let months = Double(y.years) * 12 + Double(y.months) + Double(y.days) / 30.4375
    return months > 0 ? value / months : nil
  }

  /// `1y 2m`; days only when under a month (`14d`).
  public static func compactDuration(boughtAt: Date, endedAt: Date?, now: Date = .now) -> String {
    guard let y = ymd(boughtAt: boughtAt, endedAt: endedAt, now: now), !y.isZero else { return "0d" }
    var parts: [String] = []
    if y.years > 0 { parts.append("\(y.years)y") }
    if y.months > 0 { parts.append("\(y.months)m") }
    if parts.isEmpty && y.days > 0 { parts.append("\(y.days)d") }
    return parts.isEmpty ? "0d" : parts.joined(separator: " ")
  }
}
