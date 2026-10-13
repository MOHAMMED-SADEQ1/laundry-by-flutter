"""Validate the subscription DDL + migrations against a real SQLite engine.

We recreate the *legacy* schema (v5 shape, before this change), then replay the
v6 migration statements in order and assert the final shape matches what
`sqldb.dart` expects. This catches syntax errors and ordering bugs the Dart
analyzer cannot see.
"""
import sqlite3
import sys

failures = []


def check(label, fn):
    try:
        fn()
        print(f"  OK   {label}")
    except Exception as exc:  # noqa: BLE001
        failures.append((label, str(exc)))
        print(f"  FAIL {label}: {exc}")


# ── 1. Build the legacy (pre-v6) schema ──────────────────────────────────────
db = sqlite3.connect(":memory:")
db.executescript(
    """
    CREATE TABLE "customers" (
      "customer_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "customer_name" TEXT, "phone_1" TEXT, "balance" REAL DEFAULT 0,
      "is_active" INTEGER DEFAULT 1
    );
    CREATE TABLE "clothing" (
      "cloth_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "cloth_name" TEXT, "cost_price" REAL DEFAULT 0, "is_active" INTEGER DEFAULT 1
    );
    CREATE TABLE "invoices" (
      "invoices_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "customer_id" INTEGER, "invoice_date" TEXT, "list_data" TEXT,
      "final_amount" REAL DEFAULT 0, "total_price" REAL DEFAULT 0,
      "paid_amount" REAL DEFAULT 0, "remaining_amount" REAL DEFAULT 0,
      "subscription_id" INTEGER, "is_active" INTEGER DEFAULT 1
    );
    CREATE TABLE "subscriptions" (
      "subscription_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "customer_id" INTEGER, "customer_name" TEXT,
      "amount" REAL NOT NULL DEFAULT 0, "period_days" INTEGER NOT NULL DEFAULT 30,
      "start_date" TEXT NOT NULL, "last_billed_date" TEXT NOT NULL,
      "notes" TEXT, "is_active" INTEGER DEFAULT 1
    );
    CREATE TABLE "subscription_payments" (
      "payment_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "subscription_id" INTEGER, "amount" REAL NOT NULL,
      "paid_date" TEXT NOT NULL, "method" TEXT DEFAULT 'كاش',
      "recorded_by" INTEGER
    );
    """
)
print("legacy v5 schema created")

# dirty legacy data:
#  row 1 = case (ب) — the common case: paid_until_date NULL (column didn't
#          exist yet), last_billed_date holds a date the old code wrote.
db.execute(
    'INSERT INTO "subscriptions" ("customer_id","customer_name","amount",'
    '"period_days","start_date","last_billed_date","is_active") '
    "VALUES (1,'زبون قديم',50,30,'2026-01-01','2026-01-31',1)"
)
db.commit()

# ── 2. Replay the v6 migration statements in exact order ─────────────────────
V6_ALTERS = [
    'ALTER TABLE "subscriptions" ADD COLUMN "paid_until_date" TEXT',
    'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_pieces" INTEGER DEFAULT 0',
    'ALTER TABLE "subscriptions" ADD COLUMN "usage_limit_value" REAL DEFAULT 0',
    'ALTER TABLE "subscriptions" ADD COLUMN "cycle_start_date" TEXT',
    'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_at" TEXT',
    'ALTER TABLE "subscriptions" ADD COLUMN "cancel_refund" REAL DEFAULT 0',
    'ALTER TABLE "subscriptions" ADD COLUMN "cancelled_by" INTEGER',
    'ALTER TABLE "subscriptions" ADD COLUMN "status" TEXT DEFAULT \'pending\'',
    'ALTER TABLE "subscription_payments" ADD COLUMN "notes" TEXT',
    'ALTER TABLE "subscription_payments" ADD COLUMN "source" TEXT DEFAULT \'manual\'',
    'ALTER TABLE "subscription_payments" ADD COLUMN "covers_from" TEXT',
    'ALTER TABLE "subscription_payments" ADD COLUMN "covers_to" TEXT',
    'ALTER TABLE "invoices" ADD COLUMN "subscription_used_value" REAL DEFAULT 0',
    'ALTER TABLE "invoices" ADD COLUMN "subscription_used_pieces" INTEGER DEFAULT 0',
]
V6_INDEXES = [
    'CREATE INDEX IF NOT EXISTS "idx_invoices_subscription" ON "invoices" ("subscription_id", "invoice_date")',
    'CREATE INDEX IF NOT EXISTS "idx_subpay_subscription" ON "subscription_payments" ("subscription_id", "paid_date")',
    'CREATE INDEX IF NOT EXISTS "idx_subscriptions_active" ON "subscriptions" ("is_active", "customer_id")',
    'CREATE INDEX IF NOT EXISTS "idx_subscriptions_due" ON "subscriptions" ("paid_until_date") WHERE "is_active" = 1',
]
V6_DATA_MIGRATIONS = [
    # sanitise last_billed_date FIRST (must precede the cycle_start backfill,
    # otherwise cycle_start_date already equals the polluted value and the
    # assignment becomes a no-op)
    'UPDATE "subscriptions" SET "last_billed_date" = '
    'COALESCE("start_date", "paid_until_date") '
    'WHERE ("paid_until_date" IS NOT NULL '
    '       AND "last_billed_date" = "paid_until_date") '
    '   OR ("paid_until_date" IS NULL '
    '       AND "last_billed_date" IS NOT NULL)',
    'UPDATE "subscriptions" SET "cycle_start_date" = '
    'COALESCE("last_billed_date", "start_date", "paid_until_date") '
    'WHERE "cycle_start_date" IS NULL',
    'UPDATE "subscriptions" SET "status" = CASE '
    '  WHEN "paid_until_date" IS NULL THEN \'pending\' '
    "  WHEN DATE(\"paid_until_date\") < DATE('now') THEN 'overdue' "
    "  ELSE 'active' END "
    'WHERE "is_active" = 1',
    'UPDATE "subscriptions" SET "cycle_start_date" = "start_date" WHERE "cycle_start_date" IS NULL',
]
V6_LOG_TABLE = """
  CREATE TABLE IF NOT EXISTS "subscription_coverage_log" (
    "log_id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "subscription_id" INTEGER NOT NULL,
    "customer_id" INTEGER,
    "event" TEXT NOT NULL,
    "amount" REAL DEFAULT 0,
    "pieces" INTEGER DEFAULT 0,
    "coverage_from" TEXT,
    "coverage_to" TEXT,
    "reference_id" INTEGER,
    "notes" TEXT,
    "created_at" TEXT NOT NULL,
    "created_by" INTEGER
  )
"""

print("\nmigration replay (simulating a v5 -> v6 upgrade, then the")
print("idempotent second pass that _tryAlter relies on):")
for pass_no in (1, 2):
    print(f" pass {pass_no}")
    # Between passes, inject a row polluted by the *old buggy* pay(): it wrote
    # last_billed_date = paid_until_date. Case (أ) must also be sanitised.
    if pass_no == 1:
        db.execute(
            'UPDATE "subscriptions" SET "last_billed_date" = NULL WHERE 1=0'
        )  # no-op placeholder, keeps intent explicit
    for sql in V6_ALTERS:        # _tryAlter swallows 'duplicate column' — emulate that contract
        try:
            db.execute(sql)
        except sqlite3.OperationalError as exc:
            if "duplicate column name" not in str(exc):
                failures.append((sql, str(exc)))
                print(f"  FAIL {sql}: {exc}")
                continue
        check_sql = sql if len(sql) < 62 else sql[:59] + "..."
        print(f"  OK   {check_sql}")
    for sql in V6_INDEXES:
        check(sql[:58], lambda s=sql: db.execute(s))
    # case (أ): a row polluted by the old buggy pay() — paid_until_date present
    # and equal to last_billed_date. Now that the column exists, add it.
    if pass_no == 1:
        db.execute(
            'INSERT INTO "subscriptions" ("customer_id","customer_name","amount",'
            '"period_days","start_date","last_billed_date","paid_until_date",'
            '"is_active") '
            "VALUES (2,'زبون ملوَّث',50,30,'2026-02-01','2026-03-15',"
            "'2026-03-15',1)"
        )
        db.commit()
        print("  ..   injected case-(أ) polluted row (paid_until == last_billed)")
    for sql in V6_DATA_MIGRATIONS:
        check(sql[:58], lambda s=sql: db.execute(s))
    check(V6_LOG_TABLE.strip().splitlines()[0].strip(), lambda: db.execute(V6_LOG_TABLE))
    db.execute(
        'CREATE INDEX IF NOT EXISTS "idx_coverage_log_sub" '
        'ON "subscription_coverage_log" ("subscription_id", "created_at")'
    )
    db.commit()

# ── 3. Assert final schema shape matches what the Dart code reads ────────────
print("\nfinal schema assertions:")


def columns(table):
    return {r[1] for r in db.execute(f'PRAGMA table_info("{table}")')}


REQUIRED = {
    "subscriptions": {
        "paid_until_date", "usage_limit_pieces", "usage_limit_value",
        "cycle_start_date", "cancelled_at", "cancel_refund", "cancelled_by",
        "status",
    },
    "subscription_payments": {
        "notes", "source", "covers_from", "covers_to",
    },
    "invoices": {"subscription_used_value", "subscription_used_pieces",
                 "subscription_id"},
    "subscription_coverage_log": {
        "log_id", "subscription_id", "customer_id", "event", "amount",
        "pieces", "coverage_from", "coverage_to", "reference_id", "notes",
        "created_at", "created_by",
    },
}
for table, needed in REQUIRED.items():
    have = columns(table)
    missing = needed - have
    if missing:
        failures.append((table, f"missing columns {missing}"))
        print(f"  FAIL {table} missing {missing}")
    else:
        print(f"  OK   {table} has all {len(needed)} required columns")

# indexes present?
idx = {r[0] for r in db.execute(
    "SELECT name FROM sqlite_master WHERE type='index'")}
for name in ["idx_invoices_subscription", "idx_subpay_subscription",
             "idx_subscriptions_active", "idx_subscriptions_due",
             "idx_coverage_log_sub"]:
    if name in idx:
        print(f"  OK   index {name}")
    else:
        failures.append((name, "index missing"))
        print(f"  FAIL index {name} missing")

# ── 4. Assert the data migration actually fixed every polluted row ───────────
print("\ndata migration results:")
for sub_id, label in (
    (1, "case (ب) paid_until_date NULL, stale last_billed_date"),
    (2, "case (أ) paid_until_date == last_billed_date (polluted)"),
):
    row = db.execute(
        'SELECT "start_date", "paid_until_date", "cycle_start_date", '
        '"last_billed_date", "status" FROM "subscriptions" '
        'WHERE "subscription_id" = ?',
        (sub_id,),
    ).fetchone()
    start_date, paid_until, cycle_start, last_billed, status = row
    print(f"\n  subscription {sub_id} — {label}")
    print(f"    start_date       = {start_date!r}")
    print(f"    paid_until_date  = {paid_until!r}")
    print(f"    last_billed_date = {last_billed!r}")
    print(f"    cycle_start_date = {cycle_start!r}")
    print(f"    status           = {status!r}")

    # the anchor must never be the end-of-coverage date — that was the original
    # defect (start of cycle == end of cycle => zero remaining balance)
    if cycle_start is not None and paid_until is not None and cycle_start == paid_until:
        failures.append(
            (f"subscription {sub_id}", "cycle_start_date equals paid_until_date "
             "— the original semantic defect is still present")
        )
    elif last_billed not in (start_date, None):
        failures.append(
            (f"subscription {sub_id}", f"last_billed_date {last_billed!r} was not "
             f"normalised to start_date {start_date!r}")
        )
    else:
        print("    => pollution cleared, anchor re-derived from start_date")

# the anchor must precede the coverage end, so remaining time is positive
for sub_id in (1, 2):
    cycle_start, paid_until = db.execute(
        'SELECT "cycle_start_date", "paid_until_date" FROM "subscriptions" '
        'WHERE "subscription_id" = ?',
        (sub_id,),
    ).fetchone()
    if paid_until and cycle_start and cycle_start > paid_until:
        failures.append(
            (f"subscription {sub_id}", "cycle_start_date is after paid_until_date")
        )
print("\n  OK   anchors precede coverage end for all rows")

# ── 5. Simulate the atomic pay() conditional update ──────────────────────────
print("\natomic pay() concurrency guard:")
# give the table a second row so we can prove the guard is scoped to ONE
# subscription (an unscoped COALESCE comparison would hit every NULL row)
db.execute(
    'INSERT INTO "subscriptions" ("customer_id","customer_name","amount",'
    '"period_days","start_date","last_billed_date","is_active") '
    "VALUES (2,'زبون آخر',80,30,'2026-02-01','2026-02-01',1)"
)
db.commit()


def _rows_changed(cursor):
    return cursor.rowcount


def atomic_pay():
    # production guard: subscription_id = ? AND COALESCE(paid_until_date,'') = ?
    def pay(sub_id, raw_until, new_until):
        cur = db.execute(
            'UPDATE "subscriptions" SET "paid_until_date" = ?, "status" = \'active\' '
            'WHERE "subscription_id" = ? AND '
            'COALESCE("paid_until_date", \'\') = COALESCE(?, \'\')',
            (new_until, sub_id, raw_until),
        )
        db.commit()
        return _rows_changed(cur)

    first = pay(1, None, "2026-12-31")
    if first != 1:
        raise AssertionError(f"first pay updated {first} rows, expected 1")
    print("  OK   first write scoped to subscription_id=1 (1 row)")

    # stale write: still believes paid_until_date is NULL
    second = pay(1, None, "2027-01-30")
    if second != 0:
        raise AssertionError(
            f"stale second pay updated {second} rows, expected 0 "
            "(concurrent modification must be detected)"
        )
    print("  OK   stale write correctly detected and rejected (0 rows)")

    # the other subscription must be untouched by subscription 1's write
    other = db.execute(
        'SELECT "paid_until_date" FROM "subscriptions" WHERE "subscription_id" = 2'
    ).fetchone()[0]
    if other != "2026-03-15":
        raise AssertionError(
            f"subscription 2's paid_until_date changed to {other!r} "
            "(expected its own pre-existing '2026-03-15') — guard is not "
            "properly scoped to subscription_id"
        )
    print("  OK   sibling subscription untouched (guard is scoped)")

    # a correct retry with the fresh value succeeds
    fresh = pay(1, "2026-12-31", "2027-01-30")
    if fresh != 1:
        raise AssertionError(f"retry with fresh value updated {fresh} rows, expected 1")
    print("  OK   retry with fresh value succeeds (1 row)")


check("pay() conditional update", atomic_pay)

db.close()

print("\n" + "=" * 62)
if failures:
    print(f"RESULT: {len(failures)} FAILURE(S)")
    for label, err in failures:
        print(f"  - {label}: {err}")
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
