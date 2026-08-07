# uangku

A personal money tracker built with Flutter. Track income and expenses, scan receipts with on-device OCR, categorize transactions, and view analytics — all offline-first.

## Features

- **Dashboard** — monthly income, expense, and balance with a category breakdown and month navigation
- **Transactions** — search, filter, and sort your transaction history
- **Add Transaction** — manual entry or receipt scanning
- **Receipt Scanner** — on-device OCR that extracts individual line items (name, quantity, price) alongside merchant, total, and date. Scanned data is editable in a review dialog before saving.
- **Analytics** — monthly trends, category spending, income vs expense
- **Settings** — manage categories with visual icon picker, export/import CSV, choose a currency symbol via visual selector, reset all transaction data

The UI uses an Airy Blue Material 3 theme (sky blue `#4F8CFF` / fresh green / amber accent on a cool mist surface). See `lib/core/theme/app_theme.dart`. Receipt line items are stored in a dedicated `transaction_items` table (schema v2).

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
- `lib/data/database/` — Drift DB schema (`Categories`, `Transactions`)
- `lib/data/repositories/transaction_repository.dart` — only DB access goes through here
- `lib/providers/` — hand-written Riverpod providers wiring the repository to the UI
- `lib/ui/` — feature screens: dashboard, scanner, settings, transactions
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
