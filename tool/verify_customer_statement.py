#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات كشف حساب الزبون (CustomerStatementService) على SQLite حقيقي.

يُشغّل **نفس الاستعلامات** الموجودة في
`lib/services/customer/customer_statement_service.dart` على قاعدة مصغّرة،
ثم يقارن الأرقام المشتقّة بما هو متوقّع حسابيًا.

السيناريو: زبون اشترى 3 مرات آجلًا، سدّد آخر الشهر دفعة نقدية + استهلاك
سلفة، وله اشتراك شهري استُهلك فيه 12 قطعة.
"""
import sqlite3
import sys

PASS = 0
FAIL = 0


def check(label, got, want):
    global PASS, FAIL
    ok = got == want
    if ok:
        PASS += 1
        print(f"  PASS  {label}: {got}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got!r} expected {want!r}")


def build():
    db = sqlite3.connect(":memory:")
    db.executescript(
        """
        CREATE TABLE customers (
          customer_id INTEGER PRIMARY KEY, customer_name TEXT,
          phone_1 TEXT, phone_2 TEXT, balance REAL DEFAULT 0,
          is_active INTEGER DEFAULT 1);
        CREATE TABLE invoices (
          invoices_id INTEGER PRIMARY KEY, customer_id INTEGER,
          invoice_date TEXT, final_amount REAL, paid_amount REAL,
          remaining_amount REAL, payment_method TEXT,
          subscription_id INTEGER, list_data TEXT);
        CREATE TABLE customer_payments (
          payment_id INTEGER PRIMARY KEY, customer_id INTEGER,
          amount REAL, payment_method TEXT, source TEXT, notes TEXT,
          invoice_id INTEGER, payment_date TEXT, recorded_by INTEGER);
        CREATE TABLE users (user_id INTEGER PRIMARY KEY, full_name TEXT);
        CREATE TABLE subscriptions (
          subscription_id INTEGER PRIMARY KEY, customer_id INTEGER,
          amount REAL, period_days INTEGER, status TEXT, is_active INTEGER);
        CREATE TABLE subscription_coverage_log (
          log_id INTEGER PRIMARY KEY, subscription_id INTEGER,
          customer_id INTEGER, event TEXT, amount REAL, pieces INTEGER,
          coverage_from TEXT, coverage_to TEXT, reference_id INTEGER,
          notes TEXT, created_at TEXT, created_by INTEGER);
        """
    )

    db.execute(
        "INSERT INTO customers VALUES (1,'أحمد',  '0500000000','', 25.0, 1)"
    )
    db.execute("INSERT INTO users VALUES (7,'المهندس/ محمد صادق')")

    # ─── الفواتير ───
    # (id, date, final, paid, remaining, method, sub_id, items)
    invs = [
        (1, "2026-09-01T10:00:00.000", 300.0, 150.0, 150.0, "آجل", None,
         [{"vestments": "ثوب", "content": "غسيل", "count": 3, "price": 50,
           "total_price": 150},
          {"vestments": "بنطال", "content": "غسيل", "count": 2, "price": 75,
           "total_price": 150}]),
        (2, "2026-09-10T11:00:00.000", 200.0, 50.0, 150.0, "آجل", None,
         [{"vestments": "ثوب", "content": "كوي", "count": 2, "price": 100,
           "total_price": 200}]),
        (3, "2026-09-20T12:00:00.000", 100.0, 100.0, 0.0, "كاش", None,
         [{"vestments": "بطانية", "content": "غسيل", "count": 1, "price": 100,
           "total_price": 100}]),
        # فاتورة اشتراكية — يجب ألا تُحسب ضمن المشتريات
        (4, "2026-09-25T12:00:00.000", 80.0, 0.0, 0.0, "اشتراك", 1,
         [{"vestments": "قميص", "content": "غسيل", "count": 5, "price": 16,
           "total_price": 80}]),
    ]
    import json
    for i in invs:
        db.execute(
            "INSERT INTO invoices VALUES (?,?,?,?,?,?,?,?,?)",
            (i[0], 1, i[1], i[2], i[3], i[4], i[5], i[6], json.dumps(i[7])),
        )

    # ─── دفتر الدفعات ───
    db.execute("INSERT INTO customer_payments VALUES (1,1,150.0,'كاش','manual','دفعة آخر الشهر',1,'2026-09-30T18:00:00.000',7)")
    db.execute("INSERT INTO customer_payments VALUES (2,1, 50.0,'رصيد','credit_use','استهلاك سلفة',2,'2026-09-30T18:05:00.000',7)")
    db.execute("INSERT INTO customer_payments VALUES (3,1, 20.0,'رصيد','manual','خصم رصيد',NULL,'2026-09-30T18:10:00.000',7)")

    # ─── الاشتراك + سجل القطع ───
    db.execute("INSERT INTO subscriptions VALUES (1,1,300.0,30,'active',1)")
    for i, (pcs, val) in enumerate([(5, 50.0), (4, 40.0), (3, 30.0)], start=1):
        db.execute(
            "INSERT INTO subscription_coverage_log VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (i, 1, 1, "usage", val, pcs, "2026-09-01", "2026-09-30", 4,
             "", f"2026-09-0{i}T09:00:00.000", 7),
        )
    db.commit()
    return db


# ═══════════════════ الاستعلامات المنقولة حرفيًا من الخدمة ═══════════════════

Q_INVOICES = """
SELECT invoices_id, invoice_date, final_amount, paid_amount,
       remaining_amount, payment_method, subscription_id
FROM invoices WHERE customer_id = ? AND subscription_id IS NULL
ORDER BY invoice_date ASC
"""

Q_ITEMS = """
SELECT i.invoices_id AS iid,
       json_extract(j.value, '$.vestments') AS name,
       CAST(json_extract(j.value, '$.count') AS INTEGER) AS qty,
       CAST(json_extract(j.value, '$.total_price') AS REAL) AS val
FROM invoices i, json_each(i.list_data) j
WHERE i.customer_id = ? AND i.subscription_id IS NULL
ORDER BY i.invoice_date ASC
"""

Q_PAYMENTS = """
SELECT cp.payment_date, cp.amount, cp.payment_method, cp.source,
       cp.notes, cp.invoice_id, COALESCE(u.full_name,'') AS user_name
FROM customer_payments cp
LEFT JOIN users u ON cp.recorded_by = u.user_id
WHERE cp.customer_id = ? ORDER BY cp.payment_date ASC
"""

Q_USAGE = """
SELECT created_at, subscription_id, pieces, amount, reference_id
FROM subscription_coverage_log
WHERE customer_id = ? AND event = 'usage'
ORDER BY created_at ASC
"""


def is_cash(p):
    method, source = p[2] or "", p[3] or "manual"
    return source not in ("credit_use", "cancel_refund") and method != "رصيد"


def main():
    db = build()
    cid = 1

    invs = db.execute(Q_INVOICES, (cid,)).fetchall()
    items = db.execute(Q_ITEMS, (cid,)).fetchall()
    pays = db.execute(Q_PAYMENTS, (cid,)).fetchall()
    uses = db.execute(Q_USAGE, (cid,)).fetchall()
    balance = db.execute(
        "SELECT COALESCE(balance,0) FROM customers WHERE customer_id=?", (cid,)
    ).fetchone()[0]

    print("\n[1] الفواتير غير الاشتراكية")
    check("عدد الفواتير (تُستثنى الاشتراكية)", len(invs), 3)
    check("كل الفواتير ليست اشتراكية",
          all(r[6] is None for r in invs), True)

    print("\n[2] الأصناف المأخوذة (json_each مجمَّعة)")
    summary = {}
    for r in items:
        name = (r[1] or "").strip()
        if not name:
            continue
        s = summary.setdefault(name, [0, 0.0])
        s[0] += r[2] or 0
        s[1] += r[3] or 0.0
    check("عدد بنود الأصناف الخام (2+1+1 = 4؛ فاتورة الاشتراك مستثناة)",
          len(items), 4)
    check("ثوب — العدد", summary["ثوب"][0], 5)
    check("ثوب — القيمة", summary["ثوب"][1], 350.0)
    check("بنطال — العدد", summary["بنطال"][0], 2)
    check("بنطال — القيمة", summary["بنطال"][1], 150.0)
    check("بطانية — العدد", summary["بطانية"][0], 1)
    check("قميص (اشتراكي) غير موجود في الملخّص",
          "قميص" in summary, False)

    print("\n[3] إجماليات الكشف")
    # الأعمدة: 0=id · 1=date · 2=final · 3=paid · 4=remaining · 5=method · 6=sub_id
    total_purchases = sum(r[2] or 0 for r in invs)
    total_paid = sum(r[3] or 0 for r in invs)
    total_debt = sum(r[4] or 0 for r in invs)
    credit = balance if balance > 0 else 0.0
    net = credit - total_debt if credit > 0 else -total_debt

    check("إجمالي المشتريات (600)", total_purchases, 600.0)
    check("إجمالي المسدَّد على الفواتير (300)", total_paid, 300.0)
    check("الذمة القائمة (300)", total_debt, 300.0)
    check("الرصيد الدائن (25)", credit, 25.0)
    check("صافي الموقف (-275 ⇒ عليه)", net, -275.0)
    check("عدد الفواتير المفتوحة",
          len([r for r in invs if (r[4] or 0) > 0.004]), 2)
    check("أقدم ذمة = فاتورة 2026-09-01",
          [r for r in invs if (r[4] or 0) > 0.004][0][1][:10], "2026-09-01")
    check("إجمالي القطع في الفواتير", sum(r[2] or 0 for r in items), 8)

    print("\n[4] الدفعات — فصل النقدي عن التسويات")
    cash = sum(r[1] for r in pays if is_cash(r))
    credit_used = sum(r[1] for r in pays if (r[3] or "") == "credit_use")
    check("عدد الدفعات المسجلة", len(pays), 3)
    check("المسدَّد نقدًا (150 فقط: تُستثنى credit_use وطريقة رصيد)", cash, 150.0)
    check("استهلاك السلفة (50)", credit_used, 50.0)
    check("اسم المُسجِّل يُقرأ من users", pays[0][6], "المهندس/ محمد صادق")
    check("دفعة 3 (طريقة 'رصيد') ليست نقدية",
          is_cash([r for r in pays if r[1] == 20.0][0]), False)

    print("\n[5] سجل قطع الاشتراك (الذي غُسل له)")
    check("عدد سطور الاستهلاك", len(uses), 3)
    check("مجموع القطع المستهلكة (12)", sum(r[2] for r in uses), 12)
    check("مجموع قيمة الاستهلاك (120)", sum(r[3] for r in uses), 120.0)
    check("كل سطر مرتبط بفاتورة (reference_id)",
          all(r[4] == 4 for r in uses), True)

    print("\n[6] التناسق المحاسبي")
    check("المشتريات = المسدَّد + الذمة (600 = 300 + 300)",
          total_purchases, total_paid + total_debt)
    check("الفاتورة الاشتراكية لم تُسجَّل دينًا على الزبون",
          db.execute(
              "SELECT SUM(remaining_amount) FROM invoices "
              "WHERE customer_id=1 AND subscription_id IS NOT NULL"
          ).fetchone()[0], 0.0)

    print(f"\n{'=' * 46}\n  النتيجة: {PASS} ناجح · {FAIL} فاشل\n{'=' * 46}")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
