# Wallet

Personal finance app (accounts, cards, transactions) with Supabase auth and data.

Flutter **3.44.6** (see [`.tool-versions`](.tool-versions)). Android/iOS package: `io.github.danny270793.wallet`.

## Quick start

```sh
cp .env.example.json .env.json   # then fill in real values
asdf exec flutter pub get
asdf exec flutter run --dart-define-from-file=.env.json
```

## Documentation

- [Run on an emulator or device](docs/getting-started.md)
- [Fill `.env.json`](docs/environment.md)
- [Sync Xcode and publish to the App Store](docs/app-store.md)
- [Bump app version and Flutter SDK](docs/versioning.md)

## Database (Supabase)

```mermaid
erDiagram
  wallet_accounts {
    uuid id PK
    uuid userId FK
    text name
    text description
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_cards {
    uuid id PK
    uuid userId FK
    text name
    text description
    smallint cutDay
    smallint payDay
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_categories {
    uuid id PK
    uuid userId FK
    text name
    text description
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_tags {
    uuid id PK
    uuid userId FK
    text name
    text description
    boolean hidden
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_credits {
    uuid id PK
    uuid userId FK
    timestamptz transactedAt
    int graceMonths
    int termMonths
    text description
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_transactions {
    uuid id PK
    uuid userId FK
    uuid accountId FK
    uuid cardId FK
    uuid categoryId FK
    uuid tagId FK
    uuid creditId FK
    uuid transferGroupId
    timestamptz transactedAt
    numeric value
    boolean ignore
    numeric percentage
    text description
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_assets {
    uuid id PK
    uuid userId FK
    text name
    text provider
    numeric value
    timestamptz boughtAt
    timestamptz endedAt
    numeric soldValue
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_actions {
    uuid id PK
    uuid userId FK
    text type
    text customTitle
    jsonb customPayload
    text errorMessage
    text errorStack
    text appVersion
    text os
    timestamptz createdAt
  }

  wallet_accounts_with_balance {
    uuid id PK
    uuid userId
    text name
    text description
    numeric balance
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  wallet_cards_with_balance {
    uuid id PK
    uuid userId
    text name
    text description
    smallint cutDay
    smallint payDay
    numeric balance
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  health_folders {
    uuid id PK
    uuid userId FK
    text name
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  health_pills {
    uuid id PK
    uuid userId FK
    uuid folderId FK
    text name
    text details
    text photoBase64
    int quantity
    float price
    timestamptz createdAt
    timestamptz updatedAt
    timestamptz deletedAt
  }

  health_folder_shares {
    uuid id PK
    uuid folderId FK
    uuid sharedByUserId FK
    text email
    timestamptz createdAt
    timestamptz deletedAt
  }

  habit_tracker_data {
    uuid userId PK
    jsonb habits
    int version
    timestamptz createdAt
    timestamptz updatedAt
  }

  wallet_accounts ||--o{ wallet_transactions : "accountId"
  wallet_cards ||--o{ wallet_transactions : "cardId"
  wallet_categories ||--o{ wallet_transactions : "categoryId"
  wallet_tags ||--o{ wallet_transactions : "tagId"
  wallet_credits ||--o{ wallet_transactions : "creditId"

  wallet_accounts ||--o| wallet_accounts_with_balance : "view"
  wallet_cards ||--o| wallet_cards_with_balance : "view"
  wallet_transactions }o--o| wallet_accounts_with_balance : "sum value"
  wallet_transactions }o--o| wallet_cards_with_balance : "sum value where creditId is null"

  health_folders ||--o{ health_pills : "folderId"
  health_folders ||--o{ health_folder_shares : "folderId"
```

- `wallet_transactions` is the hub. Month grouping uses `transactedAt`.
- Optional FKs: account, card, category, tag (`ON DELETE SET NULL`). Credit installments use `creditId` (`ON DELETE RESTRICT`).
- `transferGroupId` is a shared UUID for paired transfer legs, not a foreign key.
- Soft delete is `deletedAt`.
- `wallet_accounts_with_balance` / `wallet_cards_with_balance` are views: account balance is `sum(value)`; card balance excludes rows with `creditId`.
- Same project also has `health_*` and `habit_tracker_data`.

## Agents

See [AGENTS.md](AGENTS.md) (Claude: [CLAUDE.md](CLAUDE.md)).

