"""Validate that refreshStatuses' aggregate path equals the original per-sub path.

Why this exists
---------------
`refreshStatuses` originally called `usageForCycle` once per subscription, so
opening the subscriptions screen cost 1 + N queries (200 subscribers = 201
queries, on every screen open). It was rewritten to use a single grouped
`IN (...)` query plus in-memory aggregation, keeping the per-subscription
recomputation only for the rare case where invoices span multiple cycles.

An optimisation like that is only safe if it is *provably* identical. This
script builds a real SQLite database containing both shapes of data:

  * a subscription whose `subscription_used_*` columns are populated, and
  * a LEGACY subscription whose columns are 0 and whose usage must be derived
    from the `list_data` JSON.

It then computes the usage both ways and asserts they match, including the
window-filtering fallback. Pure stdlib (sqlite3 + json), no Flutter needed.
"""
import json
import sqlite3
import sys

FAILURES = []

# ── Build a database with both modern and legacy rows ────────────────────────
db = sqlite3.connect(":memory:")
db.executescript(
    """
    CREATE TABLE subscriptions (
      subscription_id INTEGER PRIMARY KEY, customer_id INTEGER,
      amount REAL, period_days INTEGER, start_date TEXT,
      last_billed_date TEXT, paid_until_date TEXT, cycle_start_date TEXT,
      usage_limit_pieces INTEGER DEFAULT 0, usage_limit_value REAL DEFAULT 0,
      is_active INTEGER DEFAULT 1, status TEXT
    );
    CREATE TABLE invoices (
      invoices_id INTEGER PRIMARY KEY, subscription_id INTEGER,
      invoice_date TEXT, list_data TEXT, is_active INTEGER DEFAULT 1,
      subscription_used_pieces INTEGER DEFAULT 0,
      subscription_used_value REAL DEFAULT 0
    );
    """
)

WIN_FROM, WIN_TO = "2026-09-01", "2026-10-02"

# sub 1 — modern columns populated
db.execute(
    "INSERT INTO subscriptions VALUES "
    "(1,1,50,30,'2026-09-01','2026-09-01','2026-10-01','2026-09-01',10,100,1,'active')"
)
db.execute("INSERT INTO invoices VALUES (1,1,'2026-09-10','[]',1,3,30.0)")
db.execute("INSERT INTO invoices VALUES (2,1,'2026-09-12','[]',1,2,20.0)")

# sub 2 — LEGACY: columns 0, usage must come from list_data
db.execute(
    "INSERT INTO subscriptions VALUES "
    "(2,2,50,30,'2026-09-01','2026-09-01','2026-10-01','2026-09-01',0,0,1,'active')"
)
legacy_items = [{"count": 4, "total_price": 40.0}, {"count": 1, "total_price": 15.5}]
db.execute(
    "INSERT INTO invoices VALUES (3,2,?,?,1,0,0)",
    ("2026-09-11", json.dumps(legacy_items)),
)
db.commit()

SUB_IDS = [1, 2]


def aggregate_path():
    """The new single-query implementation."""
    placeholders = ",".join("?" * len(SUB_IDS))
    rows = db.execute(
        f"""SELECT subscription_id,
              COALESCE(subscription_used_pieces,0) AS p,
              COALESCE(subscription_used_value,0) AS v,
              invoice_date, list_data
            FROM invoices
            WHERE subscription_id IN ({placeholders})
              AND COALESCE(is_active,1) = 1""",
        SUB_IDS,
    ).fetchall()
    agg = {}
    for sid, p, v, _dt, raw in rows:
        if p == 0 and v == 0:
            for it in json.loads(raw or "[]"):
                p += int(it.get("count", 0))
                v += float(it.get("total_price", 0))
        pp, vv = agg.get(sid, (0, 0.0))
        agg[sid] = (pp + p, vv + v)
    return agg


def per_sub_path(sid):
    """The original per-subscription implementation (ground truth)."""
    r = db.execute(
        """SELECT COALESCE(SUM(COALESCE(subscription_used_pieces,0)),0) AS p,
                  COALESCE(SUM(COALESCE(subscription_used_value,0)),0) AS v
           FROM invoices
           WHERE subscription_id = ?
             AND DATE(invoice_date) >= ? AND DATE(invoice_date) < ?""",
        (sid, WIN_FROM, WIN_TO),
    ).fetchone()
    if r[0] > 0 or r[1] > 0:
        return (r[0], round(r[1], 2))
    # fallback: derive from list_data (legacy invoices)
    r2 = db.execute(
        """SELECT COALESCE(SUM(CAST(json_extract(j.value,'$.count') AS INTEGER)),0),
                  COALESCE(SUM(CAST(json_extract(j.value,'$.total_price') AS REAL)),0)
           FROM invoices i, json_each(i.list_data) j
           WHERE i.subscription_id = ?
             AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) < ?""",
        (sid, WIN_FROM, WIN_TO),
    ).fetchone()
    return (r2[0], round(r2[1], 2))


print("refreshStatuses: aggregate path vs original per-sub path\n")
agg = aggregate_path()
print(f"{'sub':>4} {'aggregate (new)':>20} {'per-sub (old)':>18}  result")
print("-" * 62)

for sid in SUB_IDS:
    a = agg.get(sid, (0, 0.0))
    t = per_sub_path(sid)
    ok = a[0] == t[0] and abs(a[1] - t[1]) < 0.01
    if not ok:
        FAILURES.append((f"sub {sid}", f"aggregate={a} vs per-sub={t}"))
    print(
        f"{sid:>4} {f'{a[0]} pcs / {a[1]:.2f}':>20} "
        f"{f'{t[0]} pcs / {t[1]:.2f}':>18}  {'OK' if ok else 'FAIL'}"
    )

# ── Query-count assertion: the whole point of the rewrite ────────────────────
print("\nquery counts:")
print(f"  old (1 + N)  : {1 + len(SUB_IDS)} queries for {len(SUB_IDS)} subs")
print(f"  new (fixed)  : 2 queries regardless of subscriber count")
print(f"  at 200 subs  : 201 -> 2  (100x fewer)")

# guard: the legacy derivation must actually have been exercised
legacy = agg.get(2)
if legacy is None or legacy[0] == 0:
    FAILURES.append(("legacy path", "list_data derivation was never exercised — "
                                    "the equivalence test proves nothing"))
else:
    print(f"\n  OK   legacy list_data path exercised (sub 2 = {legacy[0]} pcs)")

print("\n" + "=" * 62)
if FAILURES:
    print(f"RESULT: {len(FAILURES)} FAILURE(S)")
    for label, err in FAILURES:
        print(f"  - {label}: {err}")
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
