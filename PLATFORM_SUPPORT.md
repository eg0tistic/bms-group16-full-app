# Platform Support

Status as of 2026-07-19. "Verified" below means the claim was reproduced with a build, automated test, or interactive run, not assumed.

## Windows (development platform)

- Primary development and QA platform.
- Previous release build verification succeeded. Debug builds seed demo data; release builds now open a secure first-run owner setup.
- Full workflow exercised throughout development: login, dashboard, customers, products, invoices, payments, reports, settings, utility payments, Arabic/English switching.
- Uses `sqflite_common_ffi` (bundled SQLite, no system dependency).

## Android (defense/demo target)

- Debug APK builds are verified. Release signing now requires the owner's private key via `android/key.properties`; the code no longer signs release artifacts with the public debug key.
- Package `com.group16.bms`, launcher label localized (نظام الفوترة / Retail Billing System), branded launcher icon.
- Minimum Android version: **API 24 (Android 7.0)** — this is the minimum supported by the current Flutter toolchain. Note: earlier project documents said API 21; the report must state API 24.
- `AndroidManifest.xml` includes the package-visibility `<queries>` entries required on Android 11+ for WhatsApp (`https`) and SMS links.
- Verified interactively on an Android 14 / API 34 emulator: launch, seeded login, Arabic RTL dashboard, KPI layout, navigation, and responsive reports. Verification on the physical defense phone is still required for WhatsApp handoff, PDF printing, and device-specific permissions.

## Web (verified, secondary)

- Runs on WebAssembly SQLite via `sqflite_common_ffi_web` (database persisted in IndexedDB). Setup artifacts: `web/sqlite3.wasm`, `web/sqflite_sw.js`.
- Verified interactively in a Chromium browser: app loads, demo data seeds, admin login succeeds, and the Arabic RTL dashboard renders with real SQLite data (KPIs and revenue chart).
- Release web build verified: `flutter build web --release` succeeds, including the WebAssembly compatibility dry run.
- Not verified on web: PDF generation/printing, share flows, storage eviction behavior. Treat web as a demonstration of cross-platform architecture, not a deployment target.

## iOS

- Codebase is portable in principle; declared packages have iOS implementations.
- Requires macOS and Xcode to build. **Not built or tested** — do not claim iOS support.

## Linux / macOS desktop

- Scaffolding exists from `flutter create`; the FFI database factory covers them in code.
- Not built or tested.

## Platform-specific code policy

All platform switching is isolated in one place: `lib/data/db_factory_native.dart` / `db_factory_web.dart`, selected by a conditional import in `main.dart`. No screen file contains platform checks.
