# Future Work

The current version focuses on a reliable offline-first billing workflow. Payment reversals, customer statements, user administration, password changes, audit logs, and manual backup export were delivered in the July 2026 hardening pass. The items below remain future work.

## Business Feature Improvements

### Invoice editing

- **Current limitation:** Saved invoices cannot be edited after creation.
- **Proposed future improvement:** Add a controlled edit workflow with validation, recalculated totals, customer balance adjustments, and an audit trail.
- **Why it was not included:** Editing affects invoice, payment, balance, and synchronization rules and requires broader regression testing than the current submission scope allows.

### Discounts

- **Current limitation:** Invoice totals support line quantities, prices, and VAT but no line-level or invoice-level discounts.
- **Proposed future improvement:** Support percentage and fixed discounts with explicit subtotal, discount, tax, and grand-total calculations.
- **Why it was not included:** Discounts require agreed accounting rules, localization, PDF changes, and additional invoice calculation tests.

### Inventory and stock tracking

- **Current limitation:** Products are a billing catalog and do not track stock quantities or movements.
- **Proposed future improvement:** Add stock balances, purchase and sale movements, low-stock alerts, and inventory reconciliation.
- **Why it was not included:** Inventory is a separate business domain that would require new schema, workflows, and reporting beyond billing management.

### Hard credit-limit enforcement

- **Current limitation:** Customers have a configurable credit limit with visible over-limit warning badges, but the system does not block confirming an invoice that pushes a customer past the limit.
- **Proposed future improvement:** Enforce the limit at invoice confirmation with an admin override workflow and an audit record of each override.
- **Why it was not included:** Blocking sales is a business-policy decision (many Sudanese shops extend informal credit); the advisory model was chosen deliberately, and override authorization needs role-based audit controls.

### Expense tracking

- **Current limitation:** Reports cover billing revenue and receivables only.
- **Proposed future improvement:** Add expense categories, entries, approvals, and profit-and-loss reporting.
- **Why it was not included:** Expense management is outside the defined invoice workflow and would require new schema and business rules.

### Closed invoice workflow

- **Current limitation:** A closed status is represented in shared constants and reports, but there is no completed user workflow for closing invoices.
- **Proposed future improvement:** Define eligibility rules, closing confirmation, read-only behavior, and reporting semantics for closed invoices.
- **Why it was not included:** The required accounting meaning and transition rules were not finalized, so exposing the status would risk inconsistent records.

## Reporting Improvements

### Custom date range reports

- **Current limitation:** Revenue summaries use predefined today, week, and month periods.
- **Proposed future improvement:** Add a localized date-range picker and parameterized report queries.
- **Why it was not included:** The current fixed periods cover the submission requirements and avoid adding report-state and date-boundary complexity late in stabilization.

### Charts

- **Current limitation:** Reports use metrics and progress bars rather than interactive charts.
- **Proposed future improvement:** Add accessible line, bar, and category charts with RTL labels and empty-data states.
- **Why it was not included:** A charting dependency and responsive chart QA would increase submission risk without changing core billing behavior.

### Export reports to PDF or Excel

- **Current limitation:** Individual invoices can be generated as PDF, but aggregate reports cannot be exported.
- **Proposed future improvement:** Add localized PDF reports and spreadsheet export with filters and report metadata.
- **Why it was not included:** Export formatting, Arabic font handling, and spreadsheet verification require a dedicated implementation and QA pass.

## Platform Improvements

### iOS testing using macOS and Xcode

- **Current limitation:** The Flutter project contains iOS scaffolding but has not been built or executed on iOS.
- **Proposed future improvement:** Build with Xcode on macOS and verify SQLite, printing, sharing, localization, permissions, and layouts on iPhone and iPad targets.
- **Why it was not included:** The current development environment does not provide macOS or Xcode.

### Web deployment hardening

- **Current limitation:** The web build now runs on WebAssembly SQLite (`sqflite_common_ffi_web`) and the core login → dashboard flow is verified in a browser, but PDF generation/printing, sharing, and IndexedDB storage-eviction behavior have not been verified on web.
- **Proposed future improvement:** Verify PDF and share flows in the browser, add PWA offline caching, and document IndexedDB persistence limits.
- **Why it was not included:** The defense target is the Android device; web verification was scoped to proving the database layer and core workflow.

### Drift and SQLite WASM as a long-term cross-platform database path

- **Current limitation:** SQL access is tightly coupled to `sqflite` and mobile filesystem behavior.
- **Proposed future improvement:** Migrate through a planned repository layer to Drift with SQLite WASM for stronger cross-platform queries and migrations.
- **Why it was not included:** A database migration would have a large behavioral blast radius and was explicitly excluded from the submission loop.

## Cloud Sync Improvements

### Live Supabase project testing

- **Current limitation:** Optional push sync is implemented but has not been validated end to end against a production-like Supabase project.
- **Proposed future improvement:** Configure a test project with Row Level Security, authentication, schema validation, and repeatable integration tests.
- **Why it was not included:** No live project credentials or approved remote environment were available during final stabilization.

### Conflict resolution

- **Current limitation:** The current push queue does not resolve concurrent local and remote edits.
- **Proposed future improvement:** Add record versions, timestamps, deterministic merge rules, and a user-visible conflict workflow.
- **Why it was not included:** Conflict handling requires product decisions and bidirectional synchronization architecture.

### Pull sync

- **Current limitation:** Synchronization pushes queued local changes but does not import remote records.
- **Proposed future improvement:** Add incremental pull checkpoints, local upserts, dependency ordering, and validation.
- **Why it was not included:** Pull sync can overwrite local state and requires conflict resolution and extensive integration testing first.

### Delete sync

- **Current limitation:** The current workflow primarily deactivates local records and has no complete remote deletion protocol.
- **Proposed future improvement:** Use tombstones or soft deletes with acknowledged propagation across devices.
- **Why it was not included:** Deletion semantics must be coordinated with pull sync and recovery policy to prevent data loss.

### Backup restore, encryption, and scheduling

- **Current capability:** An administrator can export a password-free JSON snapshot of business data and settings. Cloud secrets and password hashes are deliberately excluded.
- **Proposed future improvement:** Add validated restore, encrypted scheduled backups, retention controls, and a disaster-recovery test procedure.
- **Why it remains future work:** Restore can overwrite live accounting records and needs versioned schemas, explicit confirmation, encryption key management, and dedicated recovery testing.

## Arabic and PDF Improvements

Arabic PDF support is now implemented: the Cairo font is bundled as an asset and embedded in generated invoices, all invoice labels are localized (Arabic/English), and the PDF page uses full RTL layout with per-run bidirectional handling for mixed Arabic/Latin content. The remaining PDF items are below.

### Store logo in PDF header

- **Current limitation:** The PDF header shows the store name as text only.
- **Proposed future improvement:** Allow uploading a store logo in Settings and embed it in the invoice header.
- **Why it was not included:** Image storage, scaling, and print verification were outside the stabilization scope.

### Localized payment-method names in PDF

- **Current limitation:** Payment method names (Cash, Bankak, Bede, Cashi, Hawala) print in their canonical English form to match stored data.
- **Proposed future improvement:** Map method names to the invoice language in the PDF payment table.
- **Why it was not included:** Method names double as brand names in Sudan and are widely recognized in Latin script; changing them needs user feedback first.
