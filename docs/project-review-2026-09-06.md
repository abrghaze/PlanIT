# PlanIT project review — 6 September 2026

## Implementation update — 6 September 2026

The review findings below were used as an implementation checklist. The repair set now
addresses all twelve concrete findings at source level without rewriting the architecture.

| Finding | Implemented result |
| --- | --- |
| 1 — session cleanup | Credential expiry and normal sign-out preserve owner-scoped cache and unsent outbox work; profile deletion remains explicitly destructive. |
| 2 — database migration | Verified backups were created, migrations `0009` and `0010` were applied, and the local database now reports `20260906_0010` at head with no Alembic drift. |
| 3 — stale dashboards | A shared financial-data revision invalidates analytics and planning after successful account and ledger changes. |
| 4 — transaction history | Mobile synchronization follows every 200-row API page, deduplicates IDs, and stops safely. |
| 5 — offline dashboards | Analytics and planning load owner-scoped snapshots when offline or after a transient network failure, including after access-token expiry. |
| 6 — drill-down overflow | The source-transaction sheet is scrollable and no longer has the reproduced small-phone overflow. |
| 7 — portable recovery | Android uses the system Save As/Open pickers. Portable schema version 2 has an atomic, password-confirmed, idempotent restore into a fresh profile and accepts legacy version 1. Receipt binaries remain explicitly excluded. |
| 8 — recurring workflow | Outstanding due/draft occurrences remain visible, can create a reviewable draft or be skipped, refresh Activity, and are processed by a production worker. Posting the draft closes the occurrence. |
| 9 — month-end recurrence | Rules store their original local day anchor, so January 31 clamps in February and returns to March 31. |
| 10 — historical rates | The repair action asks for the first effective date instead of always recording today's date. |
| 11 — product history | Transaction items snapshot package quantity/unit; later catalog edits no longer rewrite historical unit-price analytics. |
| 12 — receipts | Mobile can list, open with a fresh private URL, retry, and explicitly delete finalized receipt images. |

The dashboard now separates account money, net receivables/payables, and personal net
position; shows monthly spending/income and the largest spending area; surfaces the next
outstanding bill; shows goal progress and required monthly pace; labels cached data and
update time; adds trend dates; and makes synchronization status actionable.

Additional hardening implemented from this report includes spreadsheet-formula-safe CSV
text, bounded off-thread Argon2 work, size-bound uploads, image signature checks, finalized
media filtering, explicit repeatable-read snapshots for analytics/exports, and a continuously
scheduled recurring worker in production Compose.

### Verification after implementation

- Backend Ruff lint and format: passed.
- Backend strict mypy: passed, 124 source files.
- Backend unit/API/PostgreSQL integration suite: **148 passed**.
- Python dependency consistency and synchronized release metadata: passed.
- Alembic current/check: `20260906_0010 (head)` and no new upgrade operations.
- Read-only PostgreSQL integrity scan: no duplicate emails, cross-owner/orphan transactions,
  bad line arithmetic, invalid indexes, unvalidated constraints, disabled integrity triggers,
  invalid recurrence anchors, or incoherent product snapshots.
- Two custom-format PostgreSQL backups were created before migrations `0009` and `0010`; the
  latest archive's table of contents is readable by `pg_restore`.
- Before the Flutter SDK was removed from this workstation at the owner's request, the 71-test
  mobile suite and all five regression probes passed. Mobile changes added afterward require
  the repository CI's pinned Flutter 3.47.1 format/analyze/test/build gates; this document does
  not mislabel those newer changes as locally compiled.

Still required before a public-production claim: a real-phone end-to-end run against an HTTPS
staging API, live object-storage tests, load/security scanning, managed backup/PITR and alert
verification, release signing, and verified-email/password-recovery product work. Those need
deployment accounts, infrastructure, or device interaction; they are not source-code defects
that can be honestly certified from this workstation.

## Original review verdict

The remainder of this document is the preserved pre-fix review at commit `9b2e661`;
references such as “currently” and “needed” describe that baseline, not the implementation
status summarized above.

PlanIT has a useful foundation, but I would currently treat it as a development/beta application, not a finished financial app ready to depend on without safeguards. The principal issues are data preservation, dashboard consistency, incomplete mobile workflows, and a local database that is behind the code's migration history.

This review found actual failures that the existing automated tests do not cover. Improving visual design is worthwhile, but preserving transactions and displaying trustworthy amounts should come first. A rewrite is not justified by these findings: the existing architecture can be improved incrementally.

Scope: backend/domain logic, authentication, PostgreSQL schema and selected integrity checks, mobile storage and synchronization, accounts/transactions, analytics, purchases/media, recurring plans/goals, privacy/export, tests, and deployment configuration. Source reviewed at `main`, commit `9b2e661`. This is not a guarantee that every possible defect has been found or a penetration-test certification.

No application code, database contents, migrations, or GitHub state were changed during the review. Only this report and local, ignored review diagnostics were added.

## What was actually verified

| Check | Result from this review |
| --- | --- |
| Backend unit/API tests | 112 passed |
| Existing Flutter tests | 71 passed |
| Backend Ruff lint / format | Passed; 172 files already formatted |
| Backend mypy | Passed; 124 source files checked |
| Python dependency consistency, `pip check` | Passed; this is not a vulnerability scan |
| Flutter static analysis | No issues found |
| Repository release metadata validator | Passed; version 0.10.0 |
| Five additional mobile regression probes | All five failed their desired-behavior assertions; findings 1, 3–6 below |
| Read-only local PostgreSQL checks | Selected integrity checks clean; migration mismatch found |
| Alembic schema check | Failed: `Target database is not up to date` |

The five mobile probes used the real relevant application classes, in-memory Drift databases, mocked network responses, and a phone-sized widget surface. They do not constitute a physical-device test. Automatic provider retries were disabled in the offline probe to expose its underlying network error directly.

### Database findings

The configured local `planit` database is PostgreSQL 18.0, with 30 public tables. Read-only checks found:

- No duplicate normalized-email groups.
- No orphaned transactions or transactions linked to another owner's account.
- No invalid/unready public indexes, unvalidated public constraints, or disabled integrity triggers.
- No existing transaction-item totals inconsistent with the application's half-even arithmetic.

However, its recorded revision is `20260830_0008`; the repository head is `20260901_0009`. These clean checks therefore do **not** mean the database matches the current application. They also do not prove backup recoverability, absence of physical corruption, or every business invariant.

I did not rerun the PostgreSQL integration suite: the configured database role cannot create a disposable database, and I did not repurpose your working database or older QA databases. No migration was applied. No physical-phone test, fresh release build, live S3 test, production deployment inspection, load test, dependency vulnerability scan, or backup-restore exercise was performed in this review.

## Priority findings

Priority meanings: **P1** should be addressed before relying on PlanIT for important records; **P2** is an important correctness/usability repair. “Reproduced” means an executed diagnostic demonstrated the behavior. “Source-confirmed” means the relevant implementation paths were inspected, without claiming a full device/server reproduction.

### 1. P1 — Session expiry can delete transactions that never synchronized

**Evidence: reproduced.** I queued one local expense, then restored a session whose refresh token had expired. The pending-operation count changed from **1 to 0**, without a successful upload.

Session cleanup invokes `clearOwnerData`, which deletes both cached records and the outbox containing unsent work. The same cleanup is used for certain authentication failures and explicit sign-out. Clearing disposable cache is different from deleting the only copy of a pending expense.

**Needed:** separate credential cleanup from pending-work retention; preserve owner-isolated drafts for reauthentication; provide an explicit warning/export/discard choice before destructive sign-out; test expiry, revoked credentials, offline restart, and account switching.

Sources: [session cleanup](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/core/auth/data/auth_repository.dart:50), [owner-data deletion](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/core/database/app_database.dart:786).

### 2. P1 — The local database still enforces an older rounding rule

**Evidence: reproduced through read-only SQL and Alembic.** Migration `0009` changes the transaction-item check from PostgreSQL `round(...)` to `planit_round_half_even(...)`. The local database still has the older check.

For the exact decimal value `0.00005`, the old rule returns `0.0001`, while the application's rule returns zero at four decimal places. Valid application-calculated line totals can consequently be rejected by the database on rounding-boundary cases. I found no currently stored mismatching items; this is a schema/deployment mismatch, not evidence that existing balances are corrupted.

**Needed:** take and verify a backup, review/apply the pending migration, rerun Alembic comparison and PostgreSQL integration tests, and test fractional quantities with half-way rounding. Add a startup/readiness or deployment check for schema revision compatibility.

Source: [pending rounding migration](C:/Users/Lenovo/Desktop/PlanIT/backend/alembic/versions/20260901_0009_consistent_decimal_rounding.py:19).

### 3. P1 — Dashboard balances can remain stale after successful changes

**Evidence: reproduced.** A dashboard first displayed **1,000 MAD**. Creating an included account with **200 MAD** succeeded, and the mocked server's total became **1,200 MAD**. Reading the same dashboard provider still returned **1,000 MAD**; it made no second analytics request.

The analytics provider depends on authentication, not ledger/account changes. Several mutation controllers refresh accounts or transactions without invalidating analytics/planning. Home preferentially uses the existing analytics total, so freshly updated account rows and the headline can disagree. Manual dashboard refresh can conceal this gap.

**Needed:** establish a shared financial-data revision/invalidation mechanism covering account changes, posting, corrections, transfers, debt payments, and successful synchronization. Refresh linked-account goal progress too. Distinguish pending estimates from server-confirmed amounts.

Sources: [analytics provider](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/application/providers.dart:16), [account creation](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/accounts/application/account_controller.dart:55), [Home headline](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/home/presentation/home_screen.dart:169).

### 4. P2 — Older transaction history becomes unreachable on a fresh installation

**Evidence: reproduced.** With 201 available server transactions, the mobile fetch returned only 200. It issues one `limit: 200` request and never requests the next page, although the backend supports offsets.

Activity searches the locally available records. Transaction detail also depends on that local list and does not fetch a missing transaction by ID. Consequently, a user with a longer history can see incomplete Activity results or fail to open an older transaction linked from analytics. This does not delete the older server records.

**Needed:** paginated history/server-side search, visible loading-more behavior, and fetch-by-ID for detail/deep links. Test reinstall/sign-in with at least 1,000 records, filters, and pending local transactions.

Sources: [single-page fetch](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/transactions/data/transactions_api.dart:21), [server pagination](C:/Users/Lenovo/Desktop/PlanIT/backend/app/api/v1/transactions.py:79), [local-only detail lookup](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/transactions/presentation/transaction_detail_screen.dart:25).

### 5. P2 — Cached dashboards fail offline after access-token expiry

**Evidence: reproduced.** I stored a valid analytics snapshot and restored an offline session with an expired access token but a still-valid refresh token. The auth state correctly remained available offline, but loading analytics raised `NETWORK_UNAVAILABLE` instead of returning its saved snapshot.

The provider requires a successful token refresh before calling the repository that contains the cache fallback. Planning uses the same ordering. Thus “cached data available offline” is not reliable throughout the session lifecycle.

**Needed:** allow the authenticated owner's saved read models to load during transient connectivity failures, label their timestamp, and keep online writes/revoked-session handling appropriately restricted. Test both analytics and planning beyond access-token expiry.

Sources: [analytics authentication gate](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/application/providers.dart:23), [unreached cache fallback](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/data/analytics_repository.dart:12), [planning provider](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/planning/application/providers.dart:19).

### 6. P2 — Analytics transaction drill-down overflows a phone screen

**Evidence: reproduced in a widget test.** Opening a category with 12 linked transactions at a 390 × 844 logical-pixel phone size produced `A RenderFlex overflowed by 457 pixels on the bottom`.

The modal uses a non-scrollable `Column`. It also limits links to 12 and identifies rows by shortened transaction IDs, which makes investigation difficult even when the layout fits.

**Needed:** a bounded scrollable/draggable sheet or full transaction-results page. Display merchant/payee, date, amount and currency; support all results. Add small-screen and enlarged-text widget tests.

Source: [source transaction sheet](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/presentation/analytics_screen.dart:108).

### 7. P2 — “Portable backup” is not yet a complete phone recovery workflow

**Evidence: source-confirmed.** Android/iOS file saving uses the application's documents directory and returns a filesystem path. Settings shows that path in a snackbar; there is no native Save As/share action. There is also no implemented backup import/restore route or mobile restore workflow. The JSON export contains media metadata rather than the receipt image files themselves.

App-specific Android files are not an independent backup: other apps cannot normally access internal files, and app-specific files are removed on uninstall. See [Android's storage documentation](https://developer.android.com/training/data-storage/app-specific).

**Needed:** user-controlled secure export/share, clear backup contents, a versioned and validated restore flow, and a real-device export → uninstall/reinstall or replacement-device → restore test. Until restoration exists, call this a data export rather than implying guaranteed recovery. Consider password-protected exported archives because they contain financial data.

Sources: [private-directory saver](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/settings/data/privacy_file_saver_io.dart:6), [export feedback](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/settings/presentation/settings_screen.dart:31), [backup implementation](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/privacy.py:164), [available privacy routes](C:/Users/Lenovo/Desktop/PlanIT/backend/app/api/v1/privacy.py:55).

### 8. P2 — Recurring reminders have an incomplete mobile workflow

**Evidence: source-confirmed.** Processing a due rule creates an occurrence and advances its next due date. The summary includes outstanding `upcoming` occurrences, but the mobile adapter discards that field and retains only rules, totals, and goals. The screen displays the rule's next date rather than the outstanding occurrence, and the backend's record-occurrence action is not exposed there.

For reminder-only bills, the due occurrence can therefore stop being visible in the screen's “Next due” list after processing, without the bill being recorded. Auto-created drafts also do not trigger a ledger refresh in this screen.

**Needed:** an outstanding-bills list with clear due/overdue/draft/recorded states; a record-to-draft action; explicit skip/snooze semantics; refresh Activity after draft creation. If reminders are promised while the app is closed, implement and verify notifications plus an actual scheduled worker. The production Compose file currently defines migration and API services, not a recurring-worker schedule.

Sources: [due processing](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/planning.py:231), [discarded summary fields](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/planning/data/planning_api.dart:26), [recurring screen](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/planning/presentation/recurring_screen.dart:99), [production services](C:/Users/Lenovo/Desktop/PlanIT/infra/docker-compose.production.yml:45).

### 9. P2 — Month-end recurring dates drift after February

**Evidence: reproduced with the domain function.** Repeated monthly advancement produced **31 January → 28 February → 28 March → 28 April**. The implementation clamps the current date and then uses that clamped date as the next month's anchor.

**Needed:** define the intended rule explicitly: original day-of-month versus last day of month. Store the original anchor and preserve it across short months. Test several consecutive months, leap years, quarterly rules, and timezone/DST boundaries. If clamped-day drift were intentional, the UI would need to explain that unusual behavior.

Source: [recurrence calculation](C:/Users/Lenovo/Desktop/PlanIT/backend/app/domain/planning/policies.py:40).

### 10. P2 — The exchange-rate repair action cannot fix historical missing rates

**Evidence: source-confirmed UI path plus reproduced domain behavior.** The dashboard's Add Rate action always supplies `DateTime.now()`. The backend correctly selects rates effective at or before each transaction. Adding today's rate therefore leaves yesterday's foreign-currency expense unconverted; the probe still returned no conversion.

**Needed:** allow an explicit effective date, explain which dates/transactions are missing rates, and let users review rate history. Do not silently backdate a rate or present an incomplete converted total as exact.

Sources: [rate timestamp in UI](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/presentation/analytics_screen.dart:204), [historical conversion policy](C:/Users/Lenovo/Desktop/PlanIT/backend/app/domain/analytics/policies.py:120).

### 11. P2 — Editing a product changes historical price-per-unit analytics

**Evidence: reproduced in memory.** An unchanged 10 MAD purchase showed **10 MAD/litre** for a 1-litre product. Changing only the catalog package size to 2 litres made the same historical purchase show **5 MAD/litre**.

Analytics reads the product's current package size. Product updates allow that size to change, while receipt line items do not preserve the historical package size/unit needed for this calculation.

**Needed:** snapshot package quantity/unit on purchase lines, or treat a changed package as a new immutable variant. Historical unit prices should not change just because today's catalog description changes. Plan any migration of old data carefully rather than inventing missing historical sizes.

Sources: [normalization from current catalog](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/analytics.py:513), [mutable package fields](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/purchases.py:355).

### 12. P2 — Receipt/image upload is not paired with a viewing workflow

**Evidence: source-confirmed.** Mobile exposes upload/reserve/finalize and “Add receipt image,” but I found no corresponding media-list/read-URL adapter and image-viewing workflow. Backend read support exists, but it is not integrated into these mobile screens.

**Needed:** attachment lists, thumbnails, full-screen viewing, download/share as appropriate, retry states, and explicit deletion. Verify signed-URL expiry and owner permissions against real storage. Users should be able to reopen the receipt they just saved.

Sources: [mobile media adapter](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/purchases/data/media_api.dart:15), [receipt action](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/transactions/presentation/transaction_detail_screen.dart:234).

## Security and operational improvements before a public launch

These are additional hardening needs, not a claim that an account was compromised.

1. **Neutralize spreadsheet formulas in CSV text fields.** An in-memory export preserved a note of `=1+1` unchanged. Account names, notes, and other user text are passed directly to the CSV writer. Quoting CSV syntax does not itself prevent spreadsheet interpretation of formulas. Protect free-text cells and test supported spreadsheet programs without altering numeric amounts. Sources: [CSV construction](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/privacy.py:103), [OWASP CSV injection guidance](https://owasp.org/www-community/attacks/CSV_Injection). No spreadsheet application or malicious formula was executed in this review.

2. **Bound authentication work.** Argon2id is a good password-storage choice, but its synchronous hash/verify functions are called inside async request handling. Offload the expensive work with bounded concurrency, and add signup/overall abuse controls rather than relying only on per-login throttling. Load-test latency and memory on the intended hosting size. Sources: [registration hash call](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/auth.py:61), [password implementation](C:/Users/Lenovo/Desktop/PlanIT/backend/app/infrastructure/security/passwords.py:6). This is a source-level concurrency risk, not a measured production incident.

3. **Strengthen upload limits and verification.** The signed PUT binds content type but not declared size; finalization checks object metadata, not decoded image contents. Add storage-enforced limits where supported, per-user quotas, content validation, and cleanup of abandoned reservations/objects. Test overwrite/retry behavior for still-valid upload URLs. Sources: [upload signing](C:/Users/Lenovo/Desktop/PlanIT/backend/app/infrastructure/storage.py:36), [finalization checks](C:/Users/Lenovo/Desktop/PlanIT/backend/app/application/media.py:105). No live bucket was probed.

4. **Make analytics scale and read a consistent snapshot.** The repository loads all posted/reversed transactions before the selected period's end, then loads many related collections with separate queries and large ID lists. The local database uses Read Committed. Benchmark realistic histories, reduce full-history materialization, and select an explicit consistency strategy for multi-query reports while financial writes occur. Apply the same snapshot review to portable exports. Source: [analytics facts loading](C:/Users/Lenovo/Desktop/PlanIT/backend/app/infrastructure/repositories/analytics.py:52). No load/concurrency benchmark was run, so no capacity limit is asserted here.

5. **Complete operational recovery and observability.** Verify off-device database backups through a restore drill, object-storage recovery, secret handling, error monitoring, health alerts, deployment rollback, and scheduled recurring processing. Deployment templates alone do not establish that these services are running. Add dependency/security scanning and reproducible backend dependency resolution.

6. **Complete account recovery for a public service.** Email uniqueness and strong-password validation already exist; add verified-email and forgotten-password/recovery workflows before presenting the service as a durable public account system. Consider a device lock/biometric option and a threat-model review of retained local financial data. These are product/security enhancements, not evidence that current credential storage is broken.

## How I would improve the dashboards

The app already contains income/spending KPIs, categories, merchants, trends, purchase metrics, recurring commitments, and goal progress. I would improve how these answer decisions rather than add more charts indiscriminately.

### A. Make Home answer three questions immediately

- **What do I have?** Clearly separate spendable account balances, savings, money owed to the user, money the user owes, and net position. Keep currencies and balance dates visible. Do not imply that receivables are spendable cash.
- **Where did it go?** Show personal spending for the chosen period, the largest categories, and a comparison against an equivalent previous period. Tapping a number must open the matching transactions, with the same filters.
- **Am I on track?** Show next bills, each goal's remaining amount/deadline, and a transparent contribution pace. Label forecasts as estimates and explain whether they use scheduled entries, historical averages, or manual allocations.

### B. Make the numbers explainable

- Add date labels and meaningful currency/date tooltips to the trend chart; its bottom axis currently hides labels. Source: [trend axis](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/features/analytics/presentation/analytics_screen.dart:660).
- Provide “See all” for category/product rankings rather than silently stopping at the first 10 or 8. Retain readable dates, amounts, and merchant/category labels in drill-downs.
- Put “Updated at…”, “Offline”, “Pending changes”, and “Missing exchange rates” near affected totals. Do not show a plausible-looking zero when data failed to load.
- Distinguish spending from transfers, debt repayments, reimbursements, and balance adjustments. The existing backend classifications are worth preserving and explaining in simple language.
- For partial months, compare matching elapsed periods rather than making a short month-to-date look artificially better than a complete previous month.
- Offer optional category budgets and an indicative end-of-month balance once the underlying refresh and recurring-data issues are fixed. Prevent double counting the same money as both available cash and allocated savings.

### C. Polish daily mobile use

- Make sync status actionable: pending count, latest successful sync, failed operation, retry, and conflict resolution.
- Test narrow phones, the keyboard open, landscape, long names, and 150–200% text scaling. Avoid truncated financial labels and clipped controls.
- Use consistent localized date/currency formatting and prepare French/Arabic localization and RTL if those are intended audiences.
- Explain financial terms and empty states; guide a new user through adding an account, recording an expense, and setting one goal.
- Complete attachment retrieval and backup restoration before calling those workflows finished.

## Recommended implementation order and acceptance criteria

| Stage | Work | Evidence required before moving on |
| --- | --- | --- |
| 1 — Preserve and trust data | Findings 1–5; safe migration/backup preparation | Unsynced work survives expiry and reauthentication; disposable-DB migration/integration tests pass; dashboard totals match account/ledger changes; all history remains reachable; offline cached reads work |
| 2 — Complete existing features | Findings 6–12; usable export/restore | No overflow at phone/text-scale test sizes; restore round-trip succeeds; due bills remain visible; recurring dates retain their anchor; historical prices stay stable; receipts can be reopened |
| 3 — Improve decisions and clarity | Home hierarchy, chart labels, comparison periods, goal pace, budgets if desired | Every total drills down to matching records; offline/incomplete states are unmistakable; users can explain what each balance includes |
| 4 — Qualify the intended release | Real-phone end-to-end tests, security/load checks, backups/monitoring, signing and accessible backend if hosted | A documented physical-device test run, restore drill, deployment/schema verification, and resolved release-blocking findings |

The current tests should be extended with the reproduced failures, not merely rerun unchanged. Add end-to-end cases for registration → account → expense → app restart → sign-in again → unchanged saved history; airplane mode → queued expense → token expiry → reconnect; more than 200 transactions; debt/refund/transfer effects across all dashboards; and backup export/restore. The existing mobile suite is mostly unit/contract/cache coverage, with limited full-screen interaction coverage and no complete real-device journey demonstrated by this review.

## Important distinction for your phone-only idea

The current implementation is still **Flutter + a server API + PostgreSQL**, with a local cache/outbox. Installing its APK does not make it a self-contained offline finance app. Its default API address is emulator-oriented. Source: [API configuration](C:/Users/Lenovo/Desktop/PlanIT/mobile/lib/core/network/api_config.dart:5).

A private, genuinely phone-only edition is feasible, but it is a separate architectural choice: the phone's database must become authoritative, server-dependent workflows must be implemented locally, and export/restore becomes essential. This review does not authorize or implement that conversion. Fixing the data-preservation and dashboard-consistency issues is useful whichever direction you choose.

## Reproduction material

Local review-only diagnostics are retained under the ignored QA directory, outside the normal test suite:

- [Five mobile regression probes](C:/Users/Lenovo/Desktop/PlanIT/.qa-docs/review_20260906/mobile_review_test.dart).
- [In-memory backend behavior probes](C:/Users/Lenovo/Desktop/PlanIT/.qa-docs/review_20260906/backend_probes.py) for recurrence drift, historical product prices, rate effective dates, and CSV text.
- [Read-only database checks](C:/Users/Lenovo/Desktop/PlanIT/.qa-docs/review_20260906/read_database.py).
- [Isolated database-test preflight](C:/Users/Lenovo/Desktop/PlanIT/.qa-docs/review_20260906/database_checks.py), which stopped because the configured role lacks database-creation permission.

The mobile probes intentionally assert the desired behavior and currently fail. They are evidence for the repair work, not application changes or replacements for the existing test suite. QA files are ignored by Git and are not automatically included in a commit.

**Bottom line:** the foundation is worth keeping. Prioritize preserving unsynced records, bringing the database schema up to date, and keeping totals synchronized. Then finish the existing user workflows and improve dashboard clarity. Passing today's test suite alone is not sufficient evidence that PlanIT is finished.
