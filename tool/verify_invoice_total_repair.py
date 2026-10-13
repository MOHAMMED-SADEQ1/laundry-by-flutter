#!/usr/bin/env python3
"""اختبار انحدار دائم — إصلاح مجموع الفواتير المخزَّنة بصفر.

━━ الخلل المحاسبي ━━
`InvoiceController.summation` كان حقلًا تفاعليًا (`RxDouble`) لا يُحدَّث أبدًا:
`calcSummation()` موجودة لكنها **لا تُستدعى من أي مكان**. شاشة البيع تعرض
المجموع الصحيح لأنها تحسبه لحظيًا عبر `totalValue()`، لكن
`PrintInvoiceController` كان يقرأ `summation.value` (صفر دائمًا) فيُحفظ:

    total_price = 0 · final_amount = 0 · remaining_amount = 0 · map_data.summation = 0

ويُطبع في PDF صفرًا. الأثر: إيراد مفقود كاملًا في التقارير ولوحة التحكم
والصندوق اليومي، ودَين زبائن لا يُسجَّل (فاتورة آجلة بمتبقٍّ صفر).

━━ الإصلاح ━━
1. كل قارئ للمجموع يقرأ `totalValue()` (مشتق من البنود) لا حقلًا مخزَّنًا.
2. كل تعديل على البنود يمرّ من `addItem/removeItem/setItems` فتُزامَن الحالة.
3. ترحيل تصحيحي في `SqlDB.runPendingMigrations` يعيد اشتقاق المجموع من
   `list_data` لأي فاتورة مخزَّنة بصفر.

هذا السكربت يحاكي منطق الترحيل على SQLite حقيقي، ويتحقّق من:
  * أن الفاتورة السليمة **لا تُمسّ**،
  * أن الفاتورة المخزَّنة بصفر تُصلَح إلى مجموع بنودها،
  * أن المتبقي يُعاد اشتقاقه (وفاتورة الاشتراك بلا متبقٍّ)،
  * أن الترحيل **متكرر الآمان** (تشغيله مرتين لا يُغيّر شيئًا).
"""
import json
import sqlite3
import sys

FAILURES = []


def check(label, actual, expected):
    ok = abs(float(actual) - float(expected)) < 1e-9
    if not ok:
        FAILURES.append(label)
    print(f"  {'OK  ' if ok else 'FAIL'} {label}")
    if not ok:
        print(f"        الناتج: {actual}   المتوقّع: {expected}")


def check_eq(label, actual, expected):
    ok = actual == expected
    if not ok:
        FAILURES.append(label)
    print(f"  {'OK  ' if ok else 'FAIL'} {label}")
    if not ok:
        print(f"        الناتج: {actual}   المتوقّع: {expected}")


def build_db():
    db = sqlite3.connect(":memory:")
    db.execute(
        """CREATE TABLE invoices (
             invoices_id INTEGER PRIMARY KEY,
             total_price REAL DEFAULT 0,
             final_amount REAL DEFAULT 0,
             paid_amount REAL DEFAULT 0,
             remaining_amount REAL DEFAULT 0,
             subscription_id INTEGER,
             list_data TEXT)"""
    )
    rows = [
        # 1 — سليمة: مجموعها مخزَّن صحيحًا ⇒ يجب ألا تُمسّ
        (1, 100.0, 100.0, 100.0, 0.0, None,
         '[{"count":10,"price":10,"total_price":100}]'),
        # 2 — مخزَّنة بصفر (3×10 + 2×15 = 60) بلا مدفوع ⇒ متبقي 60
        (2, 0.0, 0.0, 0.0, 0.0, None,
         '[{"count":3,"price":10,"total_price":30},'
         '{"count":2,"price":15,"total_price":30}]'),
        # 3 — مخزَّنة بصفر مع مدفوع 30 ⇒ متبقي 20
        (3, 0.0, 0.0, 30.0, 0.0, None,
         '[{"count":1,"price":50,"total_price":50}]'),
        # 4 — فاتورة اشتراك مخزَّنة بصفر ⇒ لا متبقي عليها
        (4, 0.0, 0.0, 0.0, 0.0, 7,
         '[{"count":4,"price":12.5,"total_price":50}]'),
        # 5 — بلا بنود ⇒ تبقى صفرًا
        (5, 0.0, 0.0, 0.0, 0.0, None, "[]"),
        # 6 — أرقام مخزَّنة كنص (قواعد بيانات قديمة) ⇒ 31.5
        (6, 0.0, 0.0, 0.0, 0.0, None,
         '[{"count":"3","price":"10.5","total_price":"31.5"}]'),
    ]
    db.executemany(
        "INSERT INTO invoices (invoices_id, total_price, final_amount,"
        " paid_amount, remaining_amount, subscription_id, list_data)"
        " VALUES (?,?,?,?,?,?,?)",
        rows,
    )
    db.commit()
    return db


def items_total(raw):
    """نفس منطق `SqlDB._itemsTotalFromJson`."""
    try:
        decoded = json.loads(raw or "[]")
    except (ValueError, TypeError):
        return 0.0
    if not isinstance(decoded, list):
        return 0.0
    total = 0.0
    for item in decoded:
        if not isinstance(item, dict):
            continue
        line = item.get("total_price")
        try:
            parsed_line = float(line) if line not in (None, "") else 0.0
        except (ValueError, TypeError):
            parsed_line = 0.0
        if parsed_line > 0:
            total += parsed_line
            continue
        try:
            count = float(item.get("count") or 0)
        except (ValueError, TypeError):
            count = 0.0
        try:
            price = float(item.get("price") or 0)
        except (ValueError, TypeError):
            price = 0.0
        total += price * count
    return round(total, 2)


def run_repair(conn):
    """نسخة بايثون من ترحيل `runPendingMigrations`."""
    rows = conn.execute(
        'SELECT invoices_id, paid_amount, subscription_id, list_data '
        'FROM "invoices" '
        'WHERE COALESCE(total_price, 0) = 0 AND COALESCE(final_amount, 0) = 0 '
        "  AND list_data IS NOT NULL AND TRIM(list_data) <> '' "
        "  AND TRIM(list_data) <> '[]'"
    ).fetchall()
    repaired = 0
    for inv_id, paid, sub_id, list_data in rows:
        total = items_total(list_data)
        if total <= 0:
            continue
        paid = float(paid or 0)
        is_sub = int(sub_id or 0) > 0
        remaining = 0.0 if is_sub else max(total - paid, 0.0)
        conn.execute(
            'UPDATE "invoices" SET total_price = ?, final_amount = ?,'
            " remaining_amount = ? WHERE invoices_id = ?",
            (total, total, remaining, inv_id),
        )
        repaired += 1
    conn.commit()
    return repaired


def snapshot(conn):
    return conn.execute(
        "SELECT invoices_id, total_price, final_amount, paid_amount,"
        " remaining_amount FROM invoices ORDER BY invoices_id"
    ).fetchall()


print("=" * 66)
print("  إصلاح مجموع الفواتير المخزَّنة بصفر — تحقّق على SQLite حقيقي")
print("=" * 66)

db = build_db()

print("\n[1] تشغيل الترحيل على قاعدة فيها فواتير مخزَّنة بصفر")
repaired = run_repair(db)
check_eq("عدد الفواتير المُصلَحة = 4", repaired, 4)

rows = {r[0]: r for r in snapshot(db)}

print("\n[2] الفاتورة السليمة لا تُمسّ (رقم 1)")
check("total_price", rows[1][1], 100.0)
check("final_amount", rows[1][2], 100.0)
check("remaining_amount", rows[1][4], 0.0)

print("\n[3] المخزَّنة بصفر تُصلَح إلى مجموع بنودها (رقم 2: 3×10 + 2×15)")
check("total_price", rows[2][1], 60.0)
check("final_amount", rows[2][2], 60.0)
check("remaining_amount = المجموع − المدفوع", rows[2][4], 60.0)

print("\n[4] المتبقي يُشتق بعد المدفوع (رقم 3: 50 − 30)")
check("total_price", rows[3][1], 50.0)
check("remaining_amount", rows[3][4], 20.0)

print("\n[5] فاتورة الاشتراك بلا متبقٍّ (رقم 4)")
check("total_price", rows[4][1], 50.0)
check("remaining_amount", rows[4][4], 0.0)

print("\n[6] الأرقام المخزَّنة كنص تُقرأ صحيحة (رقم 6: 3 × 10.5)")
check("total_price", rows[6][1], 31.5)

print("\n[7] فاتورة بلا بنود تبقى صفرًا (رقم 5)")
check("total_price", rows[5][1], 0.0)
check("final_amount", rows[5][2], 0.0)

print("\n[8] المتكرر الآمان: تشغيل الترحيل ثانيةً لا يُغيّر شيئًا")
mid = snapshot(db)
repaired2 = run_repair(db)
check_eq("عدد المُصلَح في التشغيل الثاني = 0", repaired2, 0)
check_eq("اللقطتان متطابقتان", snapshot(db), mid)

print("\n" + "=" * 66)
if FAILURES:
    print(f"  {len(FAILURES)} فحصًا فشل:")
    for f in FAILURES:
        print(f"    - {f}")
    sys.exit(1)
print("  ALL CHECKS PASSED")
print("=" * 66)
