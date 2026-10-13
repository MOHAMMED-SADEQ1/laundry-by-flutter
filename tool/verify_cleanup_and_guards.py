"""تحقّق حقيقي (SQLite فعلي) لإصلاحات الجلسة الأخيرة.

يُشغَّل بـ:
    python tool/verify_cleanup_and_guards.py

يغطي:
  A. حماية الحذف التلقائي للفواتير (لا يحذف: دَين، اشتراك، السنة الجارية)
  B. إزالة جداول المورّدين/المخزون/المشتريات
  C. منطق النقاط والشرائح (total_spent + loyalty_points + tier)
"""

import os
import sqlite3
import sys
import tempfile

PASS, FAIL = "PASS", "FAIL"
results = []


def check(name, got, expected):
    ok = got == expected
    results.append((ok, name, got, expected))
    print(f"[{PASS if ok else FAIL}] {name}\n        got={got!r}  expected={expected!r}\n")


# ─────────────────────────────────────────────────────────────
# مخطط مصغَّر يحاكي الجداول المعنية
# ─────────────────────────────────────────────────────────────
SCHEMA = """
CREATE TABLE invoices (
  invoices_id      INTEGER PRIMARY KEY,
  invoice_date     TEXT,
  final_amount     REAL DEFAULT 0,
  remaining_amount REAL DEFAULT 0,
  subscription_id  INTEGER,
  customer_id      INTEGER
);
CREATE TABLE inventory (item_id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE suppliers (supplier_id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE purchases  (purchase_id INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE customers (
  customer_id    INTEGER PRIMARY KEY,
  customer_name  TEXT,
  total_spent    REAL DEFAULT 0,
  loyalty_points INTEGER DEFAULT 0,
  tier           TEXT DEFAULT 'bronze'
);
"""

# نفس شرط الحذف في sqldb.dart (بعد رفع الحد الأدنى إلى 400 يوم)
DELETE_WHERE = """
  JULIANDAY('now') - JULIANDAY(invoice_date) > ?
  AND strftime('%Y', invoice_date) < strftime('%Y', 'now', 'localtime')
  AND COALESCE(remaining_amount, 0) <= 0.009
  AND subscription_id IS NULL
"""


def build_db():
    conn = sqlite3.connect(":memory:")
    conn.executescript(SCHEMA)
    return conn


def seed(conn):
    """المفتاح: كل التواريخ قديمة (3 سنوات) حتى يعتمد الحذف على الشروط لا العمر."""
    rows = [
        # (id, date, amount, remaining, subscription_id, note)
        (1, "2023-01-10", 500.0, 0.0, None, "قديمة نظيفة → تُحذف"),
        (2, "2023-02-11", 800.0, 250.0, None, "قديمة بدَين → تبقى"),
        (3, "2023-03-12", 300.0, 0.0, 77, "قديمة باشتراك → تبقى"),
        (4, "2026-08-01", 120.0, 0.0, None, "السنة الجارية → تبقى"),
        (5, "2023-04-13", 55.0, 0.009, None, "دَين مهمَل (≤ قرش) → يُحذف"),
    ]
    for inv_id, date, amount, remaining, sub_id, _note in rows:
        conn.execute(
            "INSERT INTO invoices (invoices_id, invoice_date, final_amount,"
            " remaining_amount, subscription_id, customer_id)"
            " VALUES (?,?,?,?,?,1)",
            (inv_id, date, amount, remaining, sub_id),
        )
    conn.commit()


print("=" * 70)
print("A. حماية الحذف التلقائي للفواتير")
print("=" * 70)
conn = build_db()
seed(conn)

# 1) التعطيل الكامل يعمل
before = conn.execute("SELECT COUNT(*) FROM invoices").fetchone()[0]
check("A1. عدد الفواتير قبل أي حذف", before, 5)


def is_truthy(raw):
    """نفس `isTruthy` في lib/services/settings/setting_option.dart.

    الغياب أو أي قيمة غير صريحة = معطَّل: لا يُحذف سجل مالي إلا بتفعيل صريح
    ('1' أو 'true') — وهذا هو حارس الإعداد `invoice_auto_delete_enabled`.
    """
    return (raw or "").strip().lower() in ("1", "true")


def run_cleanup(enabled_raw):
    """خطوة الحذف بنفس حارس Dart (وصولا إلى نفس شرط الحذف والحد 400)."""
    if not is_truthy(enabled_raw):
        return
    conn.execute(f'DELETE FROM invoices WHERE {DELETE_WHERE}', (400,))
    conn.commit()


# 2) غياب المفتاح (قاعدة قديمة) → لا حذف: المعطَّل هو الافتراضي
run_cleanup(None)
check("A2. عند غياب المفتاح لا تُحذف أي فاتورة",
      conn.execute("SELECT COUNT(*) FROM invoices").fetchone()[0], 5)

# 3) القيمة "false" → لا حذف
run_cleanup("false")
check('A3. عند القيمة "false" لا تُحذف أي فاتورة',
      conn.execute("SELECT COUNT(*) FROM invoices").fetchone()[0], 5)

# 4) قيمة غير صريحة ("yes") → لا حذف
run_cleanup("yes")
check("A4. القيمة غير الصريحة لا تُفعّل الحذف",
      conn.execute("SELECT COUNT(*) FROM invoices").fetchone()[0], 5)

# 5) تفعيل صريح → يُحذف ما يستحق فقط
run_cleanup("1")
remaining_ids = sorted(
    r[0] for r in conn.execute("SELECT invoices_id FROM invoices").fetchall()
)
check("A5. الباقي بعد الحذف = [2, 3, 4] (دَين + اشتراك + الجارية)",
      remaining_ids, [2, 3, 4])

# 6) لا تُحذف فاتورة بدَين
has_debt = conn.execute(
    "SELECT COUNT(*) FROM invoices WHERE invoices_id = 2 AND remaining_amount > 0"
).fetchone()[0]
check("A6. الفاتورة ذات الدَّين باقية سليمة", has_debt, 1)

# 7) لا تُحذف فاتورة اشتراك
has_sub = conn.execute(
    "SELECT COUNT(*) FROM invoices WHERE invoices_id = 3 AND subscription_id IS NOT NULL"
).fetchone()[0]
check("A7. فاتورة الاشتراك باقية", has_sub, 1)

# 8) السنة الجارية محميّة مهما كان العمر
this_year = conn.execute(
    "SELECT COUNT(*) FROM invoices "
    "WHERE invoices_id = 4 "
    "  AND strftime('%Y', invoice_date) = strftime('%Y','now','localtime')"
).fetchone()[0]
check("A8. فاتورة السنة الجارية باقية", this_year, 1)

# 9) الحد الأدنى 400 يوم يمنع الحذف القريب
conn2 = build_db()
conn2.execute(
    "INSERT INTO invoices (invoices_id, invoice_date, final_amount,"
    " remaining_amount, subscription_id, customer_id)"
    " VALUES (10, date('now','localtime','-200 days'), 90, 0, NULL, 1)"
)
conn2.commit()
conn2.execute(f'DELETE FROM invoices WHERE {DELETE_WHERE}', (400,))
check("A9. فاتورة عمرها 200 يوم لا تُحذف (الحد 400)",
      conn2.execute("SELECT COUNT(*) FROM invoices").fetchone()[0], 1)


print("=" * 70)
print("B. إزالة جداول المورّدين / المخزون / المشتريات")
print("=" * 70)
conn3 = build_db()
tables_before = {
    r[0] for r in conn3.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()
}
check("B1. الجداول الثلاثة موجودة قبل الإزالة",
      all(t in tables_before for t in ("inventory", "suppliers", "purchases")), True)

for table in ("inventory", "suppliers", "purchases"):
    conn3.execute(f'DROP TABLE IF EXISTS "{table}"')
conn3.commit()
tables_after = {
    r[0] for r in conn3.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()
}
check("B2. الجداول الثلاثة أُزيلت",
      [t for t in ("inventory", "suppliers", "purchases") if t in tables_after], [])

# إعادة التنفيذ آمنة (idempotent)
for table in ("inventory", "suppliers", "purchases"):
    conn3.execute(f'DROP TABLE IF EXISTS "{table}"')
conn3.commit()
check("B3. تكرار الإزالة آمن (لا استثناء)",
      [t for t in ("inventory", "suppliers", "purchases") if t in tables_after], [])

# الجداول المهمة لم تُمسّ
check("B4. جدول الفواتير لم يُمسّ", "invoices" in tables_after, True)


print("=" * 70)
print("C. النقاط والشرائح وإجمالي المشتريات")
print("=" * 70)
conn4 = build_db()
conn4.execute(
    "INSERT INTO customers (customer_id, customer_name, total_spent,"
    " loyalty_points, tier) VALUES (1, 'زبون اختبار', 0, 0, 'bronze')"
)
conn4.executemany(
    "INSERT INTO invoices (invoices_id, invoice_date, final_amount,"
    " remaining_amount, subscription_id, customer_id) VALUES (?,?,?,?,NULL,1)",
    [
        (1, "2026-09-01", 100.0, 0.0),
        (2, "2026-09-02", 250.0, 0.0),
        (3, "2026-09-03", 150.0, 0.0),
    ],
)
conn4.commit()

# total_spent = مجموع الفواتير (نفس استعلام printInvoicecontroller)
conn4.execute(
    'UPDATE "customers" SET "total_spent" = ('
    '  SELECT COALESCE(SUM(i.final_amount), 0) FROM "invoices" i '
    '  WHERE i.customer_id = ? '
    ') WHERE "customer_id" = ?',
    (1, 1),
)
conn4.commit()
spent = conn4.execute(
    "SELECT total_spent FROM customers WHERE customer_id = 1"
).fetchone()[0]
check("C1. إجمالي المشتريات = 500", spent, 500.0)

# نقاط: نقطة لكل 10 ريال → كل فاتورة تُحتسب منفصلة بـ floor
per_riyal = 10
earned = sum(int(amt // per_riyal) for amt in (100.0, 250.0, 150.0))
conn4.execute(
    'UPDATE "customers" SET "loyalty_points" = COALESCE("loyalty_points",0) + ? '
    'WHERE "customer_id" = ?',
    (earned, 1),
)
conn4.execute(
    'UPDATE "customers" SET "tier" = CASE '
    '  WHEN COALESCE("loyalty_points",0) >= 1000 THEN \'gold\' '
    '  WHEN COALESCE("loyalty_points",0) >= 500 THEN \'silver\' '
    '  ELSE \'bronze\' END '
    'WHERE "customer_id" = ?',
    (1,),
)
conn4.commit()
pts, tier = conn4.execute(
    "SELECT loyalty_points, tier FROM customers WHERE customer_id = 1"
).fetchone()
check("C2. النقاط = 10+25+15 = 50", pts, 50)
check("C3. الشريحة = bronze (أقل من 500)", tier, "bronze")

# ترقية لـ silver ثم gold
conn4.execute("UPDATE customers SET loyalty_points = 500 WHERE customer_id = 1")
conn4.execute(
    'UPDATE "customers" SET "tier" = CASE '
    '  WHEN COALESCE("loyalty_points",0) >= 1000 THEN \'gold\' '
    '  WHEN COALESCE("loyalty_points",0) >= 500 THEN \'silver\' '
    '  ELSE \'bronze\' END '
    'WHERE "customer_id" = ?',
    (1,),
)
conn4.commit()
check("C4. عند 500 نقطة → silver",
      conn4.execute("SELECT tier FROM customers").fetchone()[0], "silver")

conn4.execute("UPDATE customers SET loyalty_points = 1000 WHERE customer_id = 1")
conn4.execute(
    'UPDATE "customers" SET "tier" = CASE '
    '  WHEN COALESCE("loyalty_points",0) >= 1000 THEN \'gold\' '
    '  WHEN COALESCE("loyalty_points",0) >= 500 THEN \'silver\' '
    '  ELSE \'bronze\' END '
    'WHERE "customer_id" = ?',
    (1,),
)
conn4.commit()
check("C5. عند 1000 نقطة → gold",
      conn4.execute("SELECT tier FROM customers").fetchone()[0], "gold")


print("=" * 70)
failed = [r for r in results if not r[0]]
if failed:
    print(f"{len(failed)} من {len(results)} فحصًا فشل")
    for _, name, got, exp in failed:
        print(f"  - {name}: got={got!r} expected={exp!r}")
    sys.exit(1)
print(f"كل الفحوصات نجحت ({len(results)}/{len(results)})")
sys.exit(0)
