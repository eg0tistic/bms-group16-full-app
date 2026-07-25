# نظام الفوترة — Retail Billing Management System

Graduation project (Group 16), Faculty of Information Technology, Future University Sudan.
An offline-first billing management system for small Sudanese retail and service businesses.

## The problem

Most small businesses in Sudan track sales, debts, and customer balances in paper notebooks (دفاتر). Frequent, multi-day power and internet outages make cloud-only software unusable, and no widely available billing tool works fully offline with Arabic-first workflows and Sudanese payment methods.

## What this app does

- Full billing lifecycle: customers, products, invoices (Draft → Confirmed → Paid/Voided), partial payments, reasoned payment reversals, and reconciled customer balances.
- **Fully offline** on a local SQLite database — every feature works with no internet.
- **Arabic-first, fully bilingual** (Arabic RTL default, English LTR), Cairo font bundled — no network font fetching.
- **Sudan payment methods**: Cash, Bankak, Bede, Cashi, Bank Transfer, Hawala — with optional transaction reference capture for transfer reconciliation.
- **Arabic PDF invoices** (embedded Cairo font, RTL layout, localized labels) shared via WhatsApp or the system share sheet.
- Multi-currency invoices and reports (SDG/USD), kept separate so unlike currencies are never summed.
- Credit sales (بالآجل) with due dates, overdue badges, and advisory customer credit limits.
- **Utility bill payment ledger**: no Sudanese electricity, water, or telecom provider exposes a public API (confirmed by research — everything routes through the closed EBS bank switch), so this records the real, manual workflow instead: bills the shop pays to a provider on a customer's behalf, with a printable/shareable receipt. Not a live provider connection, and not presented as one.
- Currency-filtered reports dashboard (admin only), 7-day revenue chart, customer statements, and configurable VAT (17% default).
- Offline banner, sync queue for optional Supabase cloud backup (push-only, requires configuration).
- Secure first-run owner setup, PBKDF2 password hashing, Admin / Cashier lifecycle management, password changes, and an in-app audit log.
- Sudan tax-invoice business fields (address, phone, tax ID, commercial registration), JSON backup export, and database balance verification/rebuild.

## Tech stack

Flutter (Dart) · SQLite via `sqflite` (+ `sqflite_common_ffi` on desktop, `sqflite_common_ffi_web` WebAssembly on web) · Provider · `pdf` + `printing` · `url_launcher` / `share_plus` · `connectivity_plus`.

## How to run

```bash
flutter pub get

# Windows (development platform)
flutter run -d windows

# Android (demo target) — produces build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release

# Web (verified core flow)
flutter run -d chrome
```

## GitHub Pages demo

The full web build is published from the `docs/` folder:

https://eg0tistic.github.io/bms-group16-full-app/

The release APK is attached to the GitHub release and is also generated locally at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Debug builds show seeded demo accounts on the login screen (admin / cashier). Release builds never create known credentials and require the business owner to create the first administrator securely.

## Tests

```bash
flutter test
```

42 tests cover: valid demo-account seeding, secure salted password hashing, last-administrator protection, atomic invoice numbering under concurrency, foreign-key enforcement, database-level overpayment rejection, payment settlement/reversal and balance math, currency isolation in ledgers and reports, cash-drawer variance, schema migrations, Sudan phone validation, PDF generation (Arabic + English), model logic, and RTL layout.

## Documentation

- [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md) — exactly what is verified per platform (honest tiering).
- [ARCHITECTURE.md](ARCHITECTURE.md) — the shortest accurate explanation of the code and data flow.
- [FUTURE_WORK.md](FUTURE_WORK.md) — every deferred feature with the reason it was deferred.
- [DEMO_CHECKLIST.md](DEMO_CHECKLIST.md) — defense-day script and honest answers to expected questions.
- [SUPABASE_SCHEMA.sql](SUPABASE_SCHEMA.sql) — remote schema for optional cloud sync.

## Deployment limitations (documented)

- Cloud sync is push-only and has not been verified against a live, authenticated Supabase project with Row Level Security.
- JSON backup export is implemented; restore, encryption, scheduling, and retention policies remain future work.
- Android store releases require a private upload key configured from `android/key.properties.example`; the project deliberately does not use a public debug key for release signing.
- No live payment-gateway integration (Bankak/EBS/SyberPay have no public APIs); SudaPass sign-in is a placeholder pending a public API.
