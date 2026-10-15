import Foundation

/// JSON coding shared by the Supabase client and the offline cache, so a row
/// decoded from the server and the same row read back from disk are identical.
public enum WalletJSON {
  /// Accepts Postgres `timestamptz` (with or without fractional seconds) and
  /// `date` (`yyyy-MM-dd`, read as local midnight).
  public static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let raw = try container.decode(String.self)
      if let date = parseTimestamp(raw) { return date }
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unrecognized date: \(raw)")
    }
    return d
  }()

  public static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(formatTimestamp(date))
    }
    return e
  }()

  /// UTC ISO-8601 with milliseconds, like Dart's `toUtc().toIso8601String()`.
  public static func formatTimestamp(_ date: Date) -> String {
    date.formatted(
      .iso8601.year().month().day().dateSeparator(.dash)
        .time(includingFractionalSeconds: true).timeSeparator(.colon)
        .timeZone(separator: .omitted))
  }

  public static func parseTimestamp(_ raw: String) -> Date? {
    if raw.count == 10, let d = LocalDay.parse(raw) { return d }
    // Postgres can return microseconds and "+00:00"; ISO8601FormatStyle wants
    // at most milliseconds, so trim extra fraction digits first.
    var s = raw.replacingOccurrences(of: " ", with: "T")
    if let dot = s.firstIndex(of: ".") {
      let afterDot = s.index(after: dot)
      let digitsEnd = s[afterDot...].firstIndex { !$0.isNumber } ?? s.endIndex
      let digits = s[afterDot..<digitsEnd]
      let ms = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
      s.replaceSubrange(afterDot..<digitsEnd, with: ms)
    }
    if !s.hasSuffix("Z"), s.range(of: #"[+-]\d{2}(:?\d{2})?$"#, options: .regularExpression) == nil {
      s += "Z"  // Postgres `timestamp` without zone: treat as UTC.
    }
    let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    let plain = Date.ISO8601FormatStyle()
    return (try? withFraction.parse(s)) ?? (try? plain.parse(s))
  }
}

/// Decodes a number that PostgREST may send as a JSON number or as a string.
struct FlexibleDouble: Decodable {
  let value: Double
  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let d = try? c.decode(Double.self) {
      value = d
    } else {
      let s = try c.decode(String.self)
      guard let d = Double(s) else {
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not a number: \(s)")
      }
      value = d
    }
  }
}

extension KeyedDecodingContainer {
  func flexibleDouble(_ key: Key) throws -> Double {
    try decode(FlexibleDouble.self, forKey: key).value
  }

  func flexibleDoubleIfPresent(_ key: Key) throws -> Double? {
    try decodeIfPresent(FlexibleDouble.self, forKey: key)?.value
  }

  /// Reads `name` from a PostgREST embedded row: `{ "name": … }` or `[{ "name": … }]`.
  func embeddedName(_ key: Key) -> String? {
    if let one = try? decodeIfPresent(EmbeddedName.self, forKey: key) { return one.name }
    if let many = try? decodeIfPresent([EmbeddedName].self, forKey: key) { return many.first?.name }
    return nil
  }
}

struct EmbeddedName: Codable, Hashable, Sendable {
  var name: String?
}
