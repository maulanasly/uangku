# uangku

A personal money tracker built with Flutter. Track expenses against per-category monthly budgets, scan receipts with on-device OCR, categorize transactions, and view analytics — all offline-first.

## Features

- **Dashboard** — monthly spending with a budget progress bar, a daily pacing card (day-of-month progress + per-day allowance) for the current month, per-category budget bars (turns red when over limit), and month navigation
- **Budgets** — set a monthly spending limit per category in Settings; see how much is spent vs. budgeted
- **Transactions** — search, filter, and sort your transaction history, with a quick-add button matching the dashboard
- **Add Transaction** — item-based manual expense entry (category first, then one or more line items with optional weight, quantity, unit price, and total) or receipt scanning
- **Receipt Scanner** — on-device OCR that extracts individual line items (name, quantity, price) alongside merchant, total, and date. Scanned data is editable in a review dialog before saving.
- **Shopping Lists** — plan a trip as a checklist (a dedicated "Lists" tab): add items manually or scan a list/receipt to import item names, edit quantity and unit price inline, tick items off while shopping, then convert all checked items into a single expense via the review dialog. Checked items leave the list, and a list is marked completed once emptied.
- **Analytics** — 6-month spending trend, a category donut chart (tap a slice to highlight it), a "budget vs. spent" comparison for the current month, and a full category breakdown
- **Settings** — manage categories with visual icon picker, set per-category budgets, export/import CSV (line items included, so backups round-trip completely), choose a currency symbol via visual selector, reset all transaction data

The UI uses an Airy Blue Material 3 theme (sky blue `#4F8CFF` / fresh green / amber accent on a cool mist surface). See `lib/core/theme/app_theme.dart`. Receipt line items are stored in a dedicated `transaction_items` table (schema v5; a `budgets` table holds per-category monthly limits; items may carry an optional `weight`; `shopping_lists` and `shopping_list_items` store checklist state, with items cascading when a list is deleted). Deleting a transaction cascades to its items, but the dashboard's undo restores both the transaction and its line items. Money values are displayed with compact notation — `1.2K`/`1.23M` (English suffixes) for amounts of 1,000 and up (`lib/core/utils/money_format.dart`); editable inputs always use plain numbers.

## Getting Started

### Prerequisites

- Flutter SDK >=3.2.0 <4.0.0 (developed on 3.44.2)
- Dart

### Setup

1. Clone the repo.
2. Create a `.env` file in the project root (the app loads it on startup and will crash without it):

   ```env
   GEMINI_API_KEY=<your key>
   ```

   `GEMINI_API_KEY` is only required for the cloud receipt-parsing fallback (when on-device OCR fails or on web). There is no `.env.example`; create `.env` manually.
3. `flutter pub get`
4. `flutter run` (pick a device with `-d`)

### Commands

| Task | Command |
| --- | --- |
| Install dependencies | `flutter pub get` |
| Run the app | `flutter run` |
| Run tests | `flutter test` |
| Lint/typecheck | `flutter analyze` |
| Regenerate Drift code (after DB changes) | `dart run build_runner build --delete-conflicting-outputs` |

## Architecture

```
UI
 ↓
Provider / Notifier (Riverpod)
 ↓
Repository
 ↓
Database (Drift)
```

- `lib/main.dart` — entry; loads `.env`, wraps the app in a `ProviderScope`
- `lib/router/app_router.dart` — `go_router` config (single source of routes)
- `lib/data/database/` — Drift DB schema (`Categories`, `Transactions`, `TransactionItems`, `Budgets`)
- `lib/data/repositories/transaction_repository.dart` — only DB access goes through here
- `lib/providers/` — hand-written Riverpod providers wiring the repository to the UI
- `lib/ui/` — feature screens: dashboard, scanner, settings, transactions, receipts
- `lib/core/services/` — OCR (on-device + Gemini fallback), export, preferences

### Receipt OCR

Receipt scanning runs on-device or via cloud APIs:

- **iOS / macOS** — Apple Vision (text recognition)
- **Android** — Google ML Kit Text Recognition
- **Cloud fallback** — OCR.space (free API, no key needed) or Gemini (requires `GEMINI_API_KEY`)
- **Web** — only cloud APIs (OCR.space / Gemini)

All images are converted to JPEG before processing (HEIC from iOS gallery is handled automatically). Nothing is saved until the user confirms in the review dialog.

## Definition of Done

Features are merged to `master` only after `flutter analyze` and `flutter test` pass, the README is updated, and the change is verified end-to-end.
