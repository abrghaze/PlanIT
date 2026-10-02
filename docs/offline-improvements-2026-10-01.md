# Offline experience improvements — 1 October 2026

This pass improves the existing signed-in, offline-capable Android app. It does
not deploy a backend or turn server-managed features into a separate standalone
wallet. Android build number is now 14; package identity and signing are unchanged.

## Daily use

- A saved session opens immediately, even after its access token expires. Network
  refresh happens through the existing synchronization flow; an expired refresh
  token still requires sign-in for server access, never for viewing saved data.
- Analytics opens in **On this phone** mode. It calculates from local records,
  including pending posts/reversals, without requesting the server report. Choose
  a month and currency; see income, expenses, refunds, net spending, category
  breakdowns, largest expenses, and all contributing records.
- Phone reports use the phone's calendar/time zone. Currencies stay separate.
  Transfers and loan principal are not expenses. Shared expenses show their full
  cost; personal-share allocation remains a server report calculation.
- Comparisons explicitly use the full previous month. Comparing a partial current
  month against it is not a forecast or a saving-rate claim.
- Home uses live local account balances and monthly totals rather than an old
  analytics snapshot. Server net position is separately dated and labelled.
- Pending expense reversals increase estimated balance; pending income reversals
  reduce it. Posted transactions are not counted a second time.
- Refunds exceeding this month's expenses remain visible in the monthly total.
  Category budget consumption stays non-negative.
- Linked savings goals follow saved balances plus pending income/expense changes.
  Manual goals retain their saved allocation. Display calculations never change
  the source goal or server balance.

## Budgets and local data

- Browse/edit previous, current, and future months.
- Copy missing budgets from the prior month. Existing limits are kept, archived
  categories are skipped, and repeated copies do not create duplicates.
- Show the exact amount over budget; calculate warning thresholds with integer math.
- Confirm budget deletion, surface save errors, and avoid showing zero spending
  when transaction data failed to load.
- Serialize budget/template writes to prevent lost updates from overlapping saves.
- Unreadable budget/template storage raises an error and preserves its original
  bytes instead of silently deleting data.
- Refresh date-dependent displays on resume and while the app stays open.

## Exports without a connection

Settings exports transactions and balances directly from the local database,
including drafts and pending operations. CSV preserves four decimal places,
quotes special characters, and escapes user text that spreadsheets might interpret
as formulas. Balance exports separate saved balance, pending delta, and estimate.

**Save phone recovery archive** creates an owner-scoped JSON snapshot of all local
tables (including the pending-operation queue), budgets, and templates. It excludes
authentication tokens, passwords, and receipt image bytes. Keep it somewhere safe
outside the app. This is for **manual recovery**: there is no automatic import for
this format, and server portable restore must not be used with it. Existing server
backup/restore remains available separately.

## Limits that remain

- Initial registration/login needs the configured backend.
- Creating/editing server-managed goals, recurring rules, merchant/product
  catalogues, and some advanced operations retain their existing server or queued
  workflows. This pass does not promise every feature works locally.
- Local balances estimate pending generic income/expense posts and reversals.
  Specialized queued operations may need confirmation before affecting balances
  and goals.
- Local reports include only records saved on this phone, not unsynchronized
  records held on another device.
- Receipt image bytes and automatic offline archive restore are not included.
- Closing/reopening retains the database. Updates with the same package/signing
  key retain app storage; uninstalling or clearing storage deletes local records.
  Source edits do not update the installed APK.

## Verification

Regression coverage includes calculations/date boundaries, currency isolation,
pending reversals, budget arithmetic, duplicate-free copying, owner-isolated
exports, spreadsheet escaping, preservation of malformed storage, serialized
writes, session restoration without networking, linked goal projections, reactive
reports, source navigation, and a 360-pixel phone layout at 200% text size. Existing
persistence/migration tests remain in the full suite.

Verified locally on 2 October 2026: all 108 Flutter tests passed; Flutter analysis
reported no issues; formatting checked all 154 Dart files without changes;
`git diff --check` passed. This is automated verification, not a fresh test on a
physical phone. Android packaging and signature verification run separately in CI.
