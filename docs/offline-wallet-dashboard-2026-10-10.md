# PlanIT offline wallet and dashboard verification — build 16

## Audit findings and priorities

The existing application could reopen signed-in cached records and queue some
writes offline, but it was still organized around an online identity and several
specialized server-backed operations. Phone analytics were month-only. The old
recovery archive had no supported in-app restore. These gaps made the advertised
local experience incomplete even where individual repository tests passed.

Implementation priorities were (1) durable registration-free tracking, (2)
consistent phone-calculated reports with traceable totals, (3) safe offline
restore, and (4) small-screen and failure-state checks. No hosting, bank
integration, deployment, or online-authentication redesign was performed.

## What changed

- Fresh installs open a personal workspace without registration or login.
- Local accounts and exact four-decimal opening balances; income, expenses,
  refunds, categories, search/type/date filters, corrections, transfers, budgets
  and basic savings goals all persist on the phone.
- Current balances are separate from period cash flow. Transfers between local
  accounts are paired atomically and do not inflate income or expenses.
- Day, Monday–Sunday week, month, year and custom reports share one calculation
  engine. Summary/category/chart taps show contributing records; largest
  expenses open their details. Refunds, net spending and net cash flow are
  separate. Currencies are never combined or implicitly converted.
- Previous-period values and their source records are available. Current periods
  compare matching elapsed calendar dates/times, clamped for short/leap months,
  and are labeled partial. Chart buckets sum to the summary exactly.
- Monthly budgets show full-month consumption, explicitly labeled even inside
  a day/week/year report. Goals show current progress, either manually allocated
  or linked to an account balance.
- Mutation notifications refresh the reporting clock: a transaction entered
  after startup appears immediately instead of waiting for an app restart.
- Confirmed deletion with undo for money records; transfers delete/undo together.
  Accounts/categories with existing dependencies cannot be removed silently.
- Encrypted backups use AES-256-GCM with random salt/nonce and PBKDF2-HMAC-SHA256
  (210,000 iterations). A 12–256-character passphrase is required. Android's file
  picker saves/opens files offline. Restore validates the entire dataset before
  an atomic merge or explicitly confirmed replacement. Identical IDs are skipped;
  conflicting IDs are rejected without altering the wallet.
- App lock uses the phone's own unlock without an online account. Financial UI is
  hidden during privacy initialization; a previously enabled lock remains locked
  if authentication becomes unavailable or the preference cannot be read.

## Existing data and update safety

SQLite schema 6 adds one table; existing owner tables and outbox are not rebuilt
or cleared. Existing signed-in users keep their saved workspace. **More → Open
local workspace** selects the new mode. **Settings → Copy saved account records
here** makes an independent copy of downloaded income, expenses, fees and refunds.
Opening balances are adjusted so copied accounts match current saved balances,
including supported pending movements. Original records and pending operations
are untouched. Transfers and debt records stay in the original workspace.

The personal wallet is deliberately independent: it is not automatically uploaded
or reconciled with the saved online account. Switching workspaces is not moving or
deleting data. The old unencrypted owner recovery archive is not the new encrypted
wallet backup format and cannot be imported as one.

Build 16 retains application ID `com.abrghaze.planit`, increases Android version
code to 16, and uses the protected preview signing certificate (SHA-256
`7f4eee49ce6c86632186451e332d4c74c2d5077f78a1a6f4316a32c927706b4d`). Installing
over a compatible previously signed preview preserves app storage. If Android
rejects the signature, stop: do not uninstall to work around it. Installation
over the actual user's phone build still needs phone verification.

## Verification scope

The local full Flutter suite passed **132 tests**, and `flutter analyze --no-pub`
reported no issues. Generated-code and formatting checks are also required by
the signed Android build workflow.

Automated checks cover calendar boundaries and leap years, partial comparisons,
per-currency totals, transfer neutrality, refunds, drafts/pending reversals,
reconciled chart/source totals, corrections, concurrent writes, deletion/undo,
SQLite reopen, additive migration, original owner-data preservation, duplicate
prevention/conflict rollback, encrypted backup round-trip, wrong passphrases,
tampering, malformed/oversized files, reference integrity, form saves, immediate
dashboard updates, fresh local startup and screens at 360px with 200% text.

CI additionally exercises calendar tests in Africa/Casablanca, Europe/Berlin,
America/New_York and Pacific/Auckland, including actual UTC timestamps and
23/25-hour DST days. See the build run for final results; this document does not
claim a live-device test or a successful backend deployment.

Rendered Flutter dashboard screenshots were inspected for hierarchy, readable
amounts, reporting controls, categories, drill-down affordances and spacing.
This is visual review of test renders, not manual operation on a physical phone.

## Phone checklist — entirely offline

1. Install the signed update over the current PlanIT installation. Do not
   uninstall or clear app storage. For an existing account, first check its
   original records, then choose **More → Open local workspace**.
2. Enable airplane mode and switch off Wi-Fi. Your PC and Docker may be off.
3. Create a Cash account with opening balance 1,000 MAD. Add income 500 MAD,
   an expense 120 MAD under Food, and a Food refund 20 MAD dated today.
4. Current balance should be 1,400 MAD. Today's report should show income 500,
   expenses 120, refunds 20, spending after refunds 100, net cash flow 400 MAD.
5. Switch day/week/month/year/custom. Navigate back. Tap summary/category/chart
   records; check dates and amounts. Period cash flow must not include opening
   balances. A second currency must remain separate.
6. Correct the expense to 100 MAD: balance 1,420; net cash flow 420. Delete and
   undo it. Add a savings account and transfer money: combined same-currency
   balance and income/expense summaries must not change.
7. Add a monthly Food budget and a linked savings goal; verify corrections and
   transfers update the relevant progress. Try large system text.
8. Close/force-stop PlanIT, reopen, then restart the phone and reopen. All records
   and reports should remain. This is the physical-device durability check.
9. In Settings save an encrypted backup to Downloads or external storage. Keep
   its passphrase separately. Restore with Merge twice: no duplicates. Try a
   wrong password: no changes. Before trying Replace, save another backup.
10. Check device app lock and Android file picker on your phone: these native
    flows cannot be fully proven by Flutter widget tests.

## Boundaries and limitations

- This is a signed debug phone preview, not a production/store release.
- Local SQLite is protected by Android app sandbox/device storage security; it
  is not SQLCipher-encrypted. Backup encryption is a separate protection. A
  rooted/compromised phone is outside the app-lock guarantee.
- Backups require the passphrase; there is no recovery service. Keep backup files
  outside the app and ideally also outside the phone.
- Uninstalling, clearing storage, losing/resetting the phone can delete local
  data. Offline does not mean indestructible. Compatible in-place updates and
  ordinary app/phone restarts preserve the same database.
- Wallet snapshots are capped at 12 MiB and 50,000 records per collection;
  encrypted input files are capped at 20 MiB. Extremely large wallets have not
  been benchmarked on the user's hardware.
- No implicit exchange rates, bank links, recurring automation, server-only debt
  workflows, or production synchronization were added to the personal wallet.
- Full physical-phone install/update, process death/reboot, native biometric and
  file-picker behavior still require the checklist above. Automated green tests
  do not prove absence of every bug.
