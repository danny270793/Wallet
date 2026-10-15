// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "WalletCore",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
  products: [
    .library(name: "WalletCore", targets: ["WalletCore"]),
    .library(name: "WalletData", targets: ["WalletData"]),
  ],
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
  ],
  targets: [
    // Pure domain: entities and the money math. No I/O, fully unit tested.
    .target(name: "WalletCore"),
    // Supabase repositories, offline cache and ledger services.
    .target(
      name: "WalletData",
      dependencies: [
        "WalletCore",
        .product(name: "Supabase", package: "supabase-swift"),
      ]
    ),
    .testTarget(name: "WalletCoreTests", dependencies: ["WalletCore"]),
    .testTarget(name: "WalletDataTests", dependencies: ["WalletData"]),
  ]
)
