# AGENTS.md

Flutter personal money tracker app (`uangku`). Dart SDK >=3.2.0 <4.0.0.

## Commands

- `flutter pub get` — install deps
- `flutter run` — run app (pick a device with `-d`)
- `flutter test` — run tests; single file: `flutter test test/widget_test.dart`
- `flutter analyze` — lint/typecheck (uses `flutter_lints` + custom rules below)
- `dart run build_runner build --delete-conflicting-outputs` — regenerate Drift code (`lib/data/database/database.g.dart`). **Required after editing `tables.dart` or `database.dart`.**
- `dart run build_runner watch --delete-conflicting-outputs` — autogen during DB work

Run order when changing DB schema: edit tables -> `build_runner build` -> `flutter analyze` -> `flutter test`.

## .env is required

`lib/main.dart` calls `dotenv.load(fileName: ".env")` before `runApp`. `.env` is gitignored and **not** committed. The app will crash on launch without it. Scanner feature (`GeminiService`) needs:

```
GEMINI_API_KEY=<your key>
```

There is no `.env.example`; create `.env` manually before running.

## Architecture

- `lib/main.dart` — entry; loads `.env`, wraps app in `ProviderScope`
- `lib/router/app_router.dart` — `go_router` config (single source of routes)
- `lib/data/database/` — Drift DB. `database.dart` declares `AppDatabase` (`part 'database.g.dart'`); `tables.dart` defines `Categories`, `Transactions`, `TransactionItems` + `Budgets` schema; `connection/` uses conditional import (`native.dart` vs `web.dart`) for platform-specific SQLite open. `schemaVersion == 4`; `migration` seeds 3 default categories on create only.
- `lib/data/repositories/transaction_repository.dart` — only DB access goes through here
- `lib/providers/` — Riverpod providers wiring repo to UI. Providers are hand-written (`Provider`/`StreamProvider`/`FutureProvider`), **not** `@riverpod`-generated, despite `riverpod_annotation` being a dep.
- `lib/core/services/gemini_service.dart` — receipt OCR via `google_generative_ai` (model `gemini-1.5-flash`). Has separate `parseReceiptFromBytes` for web; `parseReceiptFromImage` throws on web.
- `lib/ui/` — feature screens: `dashboard`, `scanner`, `settings`, `transactions`

## Lint rules that bite

`analysis_options.yaml` enforces `require_trailing_commas`, `avoid_print`, and `prefer_const_*`. Multi-line collections/calls need trailing commas or `flutter analyze` fails. Don't use `print`; use a logger/debug.

## Tests

Only `test/widget_test.dart` (smoke test pumps `UangkuApp` inside `ProviderScope`). It exercises the real DB and router, so it needs a Flutter test environment that can open native SQLite; do not assume it's hermetic.