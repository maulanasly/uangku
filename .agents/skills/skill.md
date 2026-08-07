# Skill: Money Tracker Builder

## Purpose

Build and maintain a Flutter-based Money Tracker application that supports:

- Manual transaction entry
- Receipt image scanning
- Expense categorization
- Analytics and reporting
- Offline-first operation

---

## Agent Objectives

1. Minimize token usage.
2. Minimize file reads.
3. Reuse existing code whenever possible.
4. Make the smallest safe change.
5. Prefer modifications over rewrites.

---

## Execution Workflow

For every feature task, follow this order:

1. Create a new branch before making code changes.
2. Use Graphify as context memory first:
      - Run `graphify query "<question>"` for architecture and relationship context.
      - Run `graphify explain "<node>"` when deeper dependency explanation is needed.
3. Implement the smallest safe code change.
4. At final stage, run tests before declaring done.

Branching rule:

- Always create one branch for every feature.
- Do not implement feature changes directly on the current base branch.

Final-stage verification rule:

- Must run `flutter analyze` and `flutter test` at the end of feature work.
- A feature is not complete if final-stage checks are not executed.

---

## Tech Stack

### Framework

- Flutter
- Dart

### State Management

- Riverpod

### Navigation

- GoRouter

### Storage

Preferred:

- Drift

Alternative:

- SQLite

### OCR

Preferred order:

1. Google ML Kit Text Recognition
2. Tesseract OCR

### Charts

- fl_chart

---

## Architecture

```text
UI
 ↓
Provider / Notifier
 ↓
Repository
 ↓
Database
```

### Rules

- No business logic in Widgets.
- No database access from UI.
- Repositories own data operations.
- Providers own state orchestration.

---

## Data Models

### Transaction

```dart
class Transaction {
  final String id;
  final DateTime date;
  final double amount;
  final String category;
  final String merchant;
  final String note;
  final String? receiptImagePath;
  final TransactionType type;
}
```

### TransactionType

```dart
enum TransactionType {
  income,
  expense,
}
```

### Category

```dart
class Category {
  final String id;
  final String name;
  final String icon;
}
```

---

## Features

### Dashboard

Display:

- Monthly income
- Monthly expense
- Current balance
- Category breakdown

### Transactions

Support:

- Search
- Filter
- Sorting

### Add Transaction

Methods:

- Manual entry
- Receipt scanning

### Analytics

Display:

- Monthly trends
- Category spending
- Income vs expense

### Settings

Manage:

- Categories
- Export/import
- Preferences

---

## Receipt Scanner Workflow

```text
Capture Image
      ↓
Compress Image
      ↓
OCR
      ↓
Parse Text
      ↓
Create Draft Transaction
      ↓
User Review
      ↓
Save Transaction
```

### Requirements

Must:

- Process locally
- Allow manual correction
- Show extracted fields before save

Must Not:

- Auto-save transactions
- Upload receipt images without explicit requirement

---

## OCR Parsing Rules

### Merchant

Use:

- First meaningful text line

Ignore:

- Tax IDs
- Phone numbers
- Pure numeric lines

### Date

Supported formats:

- dd/MM/yyyy
- dd-MM-yyyy
- yyyy-MM-dd

### Total Amount

Prioritize labels:

- TOTAL
- GRAND TOTAL
- TOTAL BAYAR
- TOTAL BELANJA
- JUMLAH

If multiple values exist:

- Select the largest currency amount near a total label

---

## Performance Requirements

- Startup under 2 seconds
- Smooth scrolling
- Lazy loading for transaction lists
- Cached summaries where appropriate

---

## Export Requirements

Required:

- CSV

Optional:

- XLSX

---

## Testing Requirements

Required:

- Repository tests
- OCR parser tests
- Summary calculation tests
- Final-stage verification with `flutter analyze` and `flutter test`

Avoid:

- Trivial widget tests
- Snapshot-heavy tests

---

## Definition of Done

A feature is complete when:

- Builds successfully
- Tests pass
- Final-stage checks have been run (`flutter analyze` and `flutter test`)
- No dead code
- No unused imports
- No debug prints
- Architecture rules are respected
- No TODO placeholders remain