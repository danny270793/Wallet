import Foundation
import Testing
import WalletCore

@testable import WalletData

@Suite struct OfflineCacheTests {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

  @Test func roundTripsListsPerUser() async throws {
    let cache = OfflineCache(root: root)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let acc = Account(id: "a", userId: "u", name: "Cash", createdAt: now, updatedAt: now, balance: 12.5)
    await cache.saveList([acc], user: "u", key: CacheKey.accounts)
    #expect(await cache.loadList(Account.self, user: "u", key: CacheKey.accounts) == [acc])
    #expect(await cache.loadList(Account.self, user: "other", key: CacheKey.accounts) == nil)
    #expect(await cache.entries(user: "u").map(\.key) == ["accounts"])
    await cache.clear(user: "u")
    #expect(await cache.entries(user: "u").isEmpty)
  }

  @Test func keysMatchFlutter() {
    #expect(CacheKey.month(WalletCalendar.date(2026, 3)) == "tx_month_2026_03")
    #expect(CacheKey.year(WalletCalendar.date(2026, 1)) == "tx_year_2026")
  }
}
