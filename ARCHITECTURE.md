# Architecture and Defense Guide

This document is the shortest accurate explanation of the project. It is intentionally written for a project defense, not as a second report.

## The system in one sentence

The BMS is a Flutter application that records complete billing workflows in a local SQLite database first, then optionally pushes queued changes to Supabase when connectivity and cloud settings are available.

## Data flow

```text
User action
  -> Flutter screen and shared widgets
  -> AppProvider for session/language state
  -> focused service or DatabaseHelper
  -> SQLite transaction
  -> refreshed screen state
  -> optional sync_queue push later
```

## Four code areas

1. `lib/screens` and `lib/widgets`: user workflows and reusable presentation components.
2. `lib/providers`: the small amount of app-wide state: signed-in user and language.
3. `lib/services`: PDF, sharing, backup, optional sync, and the offline rule-based assistant.
4. `lib/data` and `lib/models`: SQLite access, business transactions, validation-ready records, and platform-specific database factories.

The large invoice screen is kept as one workflow file because the form state, calculations, validation, and save sequence change together. Shared theme, responsive layout, database access, and integrations are already extracted, which removes duplication without introducing a framework that would make the project harder to explain.

## Why offline first

SQLite is the source of truth. Invoice confirmation, payments, reversals, customer balances, cash-drawer reconciliation, and utility ledgers are committed locally and do not wait for a network request. The `sync_queue` records cloud work separately. This makes loss of connectivity a synchronization delay rather than a billing outage.

## Platform boundary

`main.dart` chooses one database factory through a conditional import:

- Android/Windows: native SQLite through `sqflite` or `sqflite_common_ffi`.
- Web: WebAssembly SQLite through `sqflite_common_ffi_web`, persisted in IndexedDB.

Screens contain no platform branches. That is why the same feature code runs on mobile, desktop, and web.

## Correctness rules worth explaining

- Invoice numbers are allocated inside the same database transaction as the invoice.
- Foreign keys and database checks protect relationships and overpayment rules even if UI validation is bypassed.
- SDG and USD totals remain separate; unlike currencies are never added together.
- Confirming, paying, reversing, or voiding records updates related balances transactionally.
- Passwords use salted PBKDF2-HMAC-SHA256; release builds do not seed demo credentials.
- Admin-only reporting is enforced in both navigation and assistant responses.

## Verification snapshot

- `flutter analyze`: zero issues.
- `flutter test`: 42 passing tests.
- `flutter build web --release`: successful.
- Chromium: seeded admin login and real SQLite dashboard data verified.
- Android 14 emulator: login, RTL dashboard, navigation, and reports verified.

See `PLATFORM_SUPPORT.md` for the exact boundary between verified and unverified platform behavior.
