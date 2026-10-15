import Foundation

/// Local calendar helpers. Like the Flutter app, all month and day grouping
/// uses the device's local calendar; timestamps are stored in UTC.
public enum WalletCalendar {
  /// Gregorian in the current time zone. Read on every access so tests and
  /// time-zone changes are picked up.
  public static var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = .current
    return c
  }

  public static func date(_ year: Int, _ month: Int, _ day: Int = 1, hour: Int = 0, minute: Int = 0) -> Date {
    // DateComponents normalizes overflow (month 13 -> next January, day 0 -> last day of previous month).
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  public static func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

  public static func startOfMonth(_ d: Date) -> Date {
    let c = calendar.dateComponents([.year, .month], from: d)
    return date(c.year!, c.month!)
  }

  public static func startOfYear(_ d: Date) -> Date { date(year(d), 1) }

  public static func year(_ d: Date) -> Int { calendar.component(.year, from: d) }
  public static func month(_ d: Date) -> Int { calendar.component(.month, from: d) }
  public static func day(_ d: Date) -> Int { calendar.component(.day, from: d) }

  public static func daysInMonth(year: Int, month: Int) -> Int {
    day(date(year, month + 1, 0))
  }

  /// First day of the month `offset` months from [d]'s month.
  public static func monthStart(_ d: Date, offset: Int) -> Date {
    date(year(d), month(d) + offset)
  }

  public static func addDays(_ d: Date, _ n: Int) -> Date {
    calendar.date(byAdding: .day, value: n, to: d)!
  }

  public static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
    year(a) == year(b) && month(a) == month(b)
  }

  /// Day [day] of the given month, clamped to the month's length; keeps a time of day.
  public static func dayInMonth(year y: Int, month m: Int, day: Int, timeFrom: Date? = nil) -> Date {
    let normalized = date(y, m)
    let ny = year(normalized), nm = month(normalized)
    let last = daysInMonth(year: ny, month: nm)
    let d = min(max(day, 1), last)
    guard let t = timeFrom else { return date(ny, nm, d) }
    let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: t)
    return calendar.date(
      from: DateComponents(
        year: ny, month: nm, day: d, hour: c.hour, minute: c.minute, second: c.second,
        nanosecond: c.nanosecond))!
  }

  /// Calendar month arithmetic keeping the day (clamped) and time of day.
  public static func addCalendarMonths(_ d: Date, _ months: Int) -> Date {
    dayInMonth(year: year(d), month: month(d) + months, day: day(d), timeFrom: d)
  }
}

/// Postgres `date` columns (`yyyy-MM-dd`), kept as local calendar dates.
public enum LocalDay {
  public static func parse(_ raw: String) -> Date? {
    let parts = raw.prefix(10).split(separator: "-")
    guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
      return nil
    }
    return WalletCalendar.date(y, m, d)
  }

  public static func format(_ d: Date) -> String {
    let c = WalletCalendar.calendar.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
}

/// Decodes/encodes a `date` column as a local midnight `Date`.
@propertyWrapper
public struct LocalDate: Codable, Hashable, Sendable {
  public var wrappedValue: Date
  public init(wrappedValue: Date) { self.wrappedValue = wrappedValue }
  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    let raw = try c.decode(String.self)
    guard let d = LocalDay.parse(raw) else {
      throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(raw)")
    }
    wrappedValue = d
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(LocalDay.format(wrappedValue))
  }
}
