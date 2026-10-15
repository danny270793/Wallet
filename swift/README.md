# Wallet — SwiftUI (iOS 26, Liquid Glass)

Native port of the [Flutter app](../flutter). Same Supabase backend, same
`wallet_*` tables, RPCs and offline cache layout, so both apps can be used
side by side with the same account.

Requires **Xcode 26** and the **iOS 26 simulator/SDK**.

## Quick start

```sh
cp swift/WalletConfig.example.plist swift/Wallet/Resources/WalletConfig.plist   # then fill in real values
open swift/Wallet.xcodeproj
```

The values are the same as the Flutter `.env.json` (`SUPABASE_URL`,
`SUPABASE_ANON_KEY`). Without the file the app shows a "not configured" screen.

## Layout

| Path | What |
|---|---|
| `Packages/WalletCore/Sources/WalletCore` | Entities and all money math (loan amortization, deferred credit schedules, credit ledger, totals, yearly projections, automatic recurring movements). No I/O. |
| `Packages/WalletCore/Sources/WalletData` | Supabase repository, offline JSON cache, multi-row ledger operations (deferred purchases, credit rescheduling, transfers, balance adjustments), error reporting to `wallet_actions`. |
| `Packages/WalletCore/Tests` | Swift Testing suites; the Flutter `test/` cases are ported here. |
| `Wallet/App` | App entry, session model, preferences (language, theme, Face ID lock), tab shell. |
| `Wallet/Features` | Screens, one folder per tab. |
| `Wallet/Components` | Shared rows, pickers, month switcher, floating summary card. |
| `Wallet/Resources` | Assets and `Localizable.xcstrings` (English and Spanish). |

The project uses a synchronized folder, so new files under `Wallet/` are picked
up by Xcode automatically.

## Tests

```sh
cd swift/Packages/WalletCore && swift test
```

## Strings

`Localizable.xcstrings` is generated from the Flutter `.arb` files (same keys)
plus `scripts/swift_only_strings.json`. After changing either:

```sh
python3 -I swift/scripts/arb_to_xcstrings.py
```

## Design (Liquid Glass)

The Flutter drawer is replaced by a floating glass tab bar that minimizes on scroll:

- **Activity** — the month's transactions. The month switcher sits in the nav
  bar; "+" is a toolbar menu (new transaction / transfer / pay card) instead of
  a speed-dial FAB.
- **Credits** — deferred card purchases for the month, filterable by card.
- **Insights** — monthly and yearly dashboards (Swift Charts) behind one
  segmented control, sharing the view options sheet.
- **Wallet** — accounts and cards with live totals, then loans, recurring
  movements, assets, categories, tags and Settings.
- **Search** — the system search tab (bottom search field).

Totals float above the tab bar on a glass card; swipe it sideways where the
Flutter app had a paged totals bar. Glass is used only on controls and the
summary card, never on list content, per Apple's guidance.
