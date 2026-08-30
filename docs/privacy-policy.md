# PlanIT privacy policy — publication draft

**Status:** This is an accurate engineering draft, not a hosted legal notice. Before store
submission, the operator must add the effective date, legal identity, contact email, support
URL, hosting regions, retention periods, and any jurisdiction-specific language, then obtain
appropriate legal review.

PlanIT stores the account and financial information a user chooses to enter so it can provide
account balances, transaction history, debts, purchase records, planning, and analytics.
This can include email address, display name, accounts, transactions, categories, tags,
people, debts, merchants, products, recurring rules, savings goals, and optional receipt
images. Passwords are stored only as one-way Argon2id hashes. Authentication sessions use
short-lived access tokens and revocable, rotated refresh tokens.

PlanIT does not sell personal data and does not enable advertising trackers. OCR and bank
connections are disabled in the default release. If either capability is offered later, its
provider, data transfer, consent flow, and cost must be disclosed before it is enabled.

Data is used to operate and secure the service, synchronize the user's devices, calculate
the financial views the user requests, prevent duplicate writes, diagnose failures using
privacy-safe operational logs, and meet legal obligations. Request logs contain route,
status, timing, and a correlation identifier; they intentionally exclude credentials,
request/response bodies, receipt contents, and financial values.

Financial data is stored in PostgreSQL and optional receipts in a private S3-compatible
bucket. The production operator must encrypt data in transit and at rest, restrict staff
access, document backup and log retention, and disclose the countries where processors
handle data. Infrastructure providers must be listed here before publication.

Authenticated users can export transactions or accounts as CSV and download a portable JSON
backup from Settings. They can permanently delete their profile after re-entering their
password and the confirmation phrase. Deletion removes private receipt objects and account
data and invalidates sessions, subject only to any retention the operator is legally required
to keep. Backup expiry and deletion schedules must be added before publication.

Users should contact **[INSERT PRIVACY EMAIL]** to request access, correction, deletion, or
other applicable privacy rights. The operator identity and postal address are **[INSERT
LEGAL OPERATOR DETAILS]**. The effective date is **[INSERT DATE]**.
