# Demo Day Checklist

## Before the defense (the night before)

1. For the prepared demo data, install a debug APK or run with `flutter run`; release builds intentionally open secure first-owner setup instead of creating known passwords.
2. **Fresh debug install matters:** demo data is seeded on first launch with dates set to "now", so clearing the app's storage before the defense makes the dashboard look alive.
3. Confirm WhatsApp is installed and logged in on the phone (needed for the invoice-sharing step, the highest-scored feature).
4. Charge the phone; set screen timeout to 10 minutes; enable Do Not Disturb.
5. Optional: keep the Windows build ready as a backup demo (`build\windows\x64\runner\Release\group16_bms.exe` — same fresh-DB advice: delete `%APPDATA%\Group 16 - Future University Sudan` first).

## Demo script (5–8 minutes)

1. Enable airplane mode → open the app → point out the offline banner. The app is fully offline.
2. Login as Admin (Arabic UI, RTL).
3. Dashboard: today's revenue, receivables, unpaid invoices, 7-day revenue chart.
4. Switch to English and back to Arabic (drawer → settings or login toggle).
5. Add a customer (show Sudan phone validation and the credit-limit field).
6. Add a product.
7. Create an invoice: pick customer, add items, show currency selector (SDG/USD) and the optional due date (بالآجل), confirm.
8. Record a partial payment — pick **Bankak** as the method and enter a transaction reference. Show it in the payment history.
9. Open the invoice PDF — point out full Arabic layout.
10. Share via WhatsApp (disable airplane mode first) — the message includes amount, status, and due date.
11. Reports (admin only): show revenue, receivables, invoice status, top customers, and top products.
12. Utility bills: record a real electricity bill payment (provider, meter number, bill amount, small service fee), generate the receipt, and explain the honest explainer banner — this is a manual ledger for a workflow shops already do, not a live provider connection (no Sudanese utility exposes a public API).
13. Show the SudaPass button on the login screen and explain the integration plan.

## Honest answers for likely committee questions

- **"How is authentication protected?"** Accounts are verified locally with a unique random salt and PBKDF2-HMAC-SHA256 at 120,000 iterations. Hash comparison is constant-time, legacy SHA-256 records are upgraded after a valid login, and release builds never seed known passwords. A production multi-device deployment would still benefit from server-side identity, recovery, rate limiting, and centrally managed sessions.
- **"Does cloud sync work?"** The offline sync queue is implemented and every write is queued locally. Pushing to Supabase requires configuring a project URL and key in Settings; no live project was provisioned, so sync is demonstrated as architecture, not as a live flow. Enqueueing is also not atomic with the business write — documented as future work.
- **"Why no real Bankak/payment API?"** No public payment APIs exist in Sudan; integration requires an EBS-licensed partnership. The app mirrors the real manual workflow: recording the payment method and transaction reference. This is documented, with SudaPass/EBS integration as future work.
- **"What Android versions?"** Android 7.0 (API 24) and above — the minimum supported by the current Flutter toolchain.
- **"What about the USD currency option?"** Invoices can be issued and settled in USD, but the customer receivables ledger is deliberately SDG-only so amounts in different currencies are never mixed. A per-currency ledger is future work.
- **"Are the utility bill payments a live provider connection?"** No, and none can be — research confirmed no Sudanese electricity, water, or telecom provider exposes a public API (everything routes through the closed EBS bank switch). The screen is a real manual ledger instead: the shop records bills it paid to the provider on the customer's behalf (the actual workflow shops already use), with a printable receipt and WhatsApp sharing. This is documented as the honest, defensible alternative to a fake integration.

## One-minute architecture answer

The screens collect input and show state. `AppProvider` holds the signed-in user and language. Services own focused integrations such as PDFs, sharing, and sync. `DatabaseHelper` is the single local data gateway and applies billing rules inside SQLite transactions. Android and desktop use native SQLite; web swaps only the database factory for WebAssembly SQLite in IndexedDB. Every business workflow remains local first, while optional cloud sync pushes queued changes later.

## If something goes wrong live

- WhatsApp share fails → show the SMS option or the PDF preview instead.
- Phone misbehaves → switch to the Windows build (identical features).
- A question you cannot answer → "That is documented as a limitation in the report" is an honest, acceptable answer.
