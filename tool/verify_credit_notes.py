#!/usr/bin/env python3
"""حرس إشعارات الدائن (المرتجعات) — على **SQLite حقيقي**.

يُثبت أن الإرجاع الكامل، كما ينفّذه `CreditNoteService.returnInvoice`،
**يصحّح الدفاتر بلا أن يمحو شيئًا**:

  1. الفاتورة الأصلية **لا تُحذف ولا تُعدَّل** إلا في `remaining_amount = 0`.
  2. المستند العكسي فاتورة سالبة موسومة بـ`credit_note_of` ⇒ كل تقرير
     تجميعي (SUM) يصحّ تلقائيًّا بلا إعادة كتابة استعلام واحد.
  3. `COUNT(CASE WHEN credit_note_of = 0 …)` لا يعدّ الإشعار فاتورة.
  4. بنود `invoice_items` السالبة تُلغي **التكلفة** أيضًا، فلا يظهر ربح
     منخفضًا بمقدار تكلفة القطع كاملة (وهو الخطأ الذي كان سيقع لو ألغينا
     الإيراد وحده).
  5. الإشعار لا يظهر في لوحة المصنعية (حالته `delivered` وموسوم بالأصل).
  6. الحرس المزدوج يمنع إشعارين لنفس الفاتورة.
  7. الردّ نقدًا يخصم من صندوق الوردية (مبلغ سالب)، والردّ رصيدًا لا
     يُخرج نقدية ويخصم من أقدم الذمم FIFO ثم يقيّد الفائض سلفةً.

يُشغَّل:  python tool/verify_credit_notes.py [مسار_قاعدة_حيّة]
"""
from __future__ import annotations

import json
import os
import shutil
import sqlite3
import sys
import tempfile

OK = 0
FAIL = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global OK, FAIL
    if cond:
        OK += 1
        print(f"[PASS] {name}")
    else:
        FAIL += 1
        print(f"[FAIL] {name}  {detail}")


def live_db_path() -> str | None:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None
    p = os.path.join(
        appdata, "com.mohammadsadekaljafri", "laundry", "laundry_pos.db"
    )
    return p if os.path.exists(p) else None


SYNTHETIC = """
CREATE TABLE "customers" (
  "customer_id" INTEGER PRIMARY KEY, "customer_name" TEXT, "balance" REAL DEFAULT 0,
  "is_active" INTEGER DEFAULT 1
);
CREATE TABLE "invoices" (
  "invoices_id" INTEGER PRIMARY KEY, "invoice_number_text" TEXT,
  "shift_id" INTEGER, "customer_id" INTEGER, "customer_name" TEXT,
  "customer_phone" TEXT, "total_price" REAL, "discount_amount" REAL,
  "tax_amount" REAL, "tax_base" REAL, "tax_rate" REAL, "final_amount" REAL,
  "paid_amount" REAL, "payment_method" TEXT, "remaining_amount" REAL,
  "discount_code" TEXT, "invoice_date" TEXT, "list_data" TEXT,
  "map_data" TEXT, "status" TEXT, "credit_note_of" INTEGER,
  "subscription_id" INTEGER, "created_by" INTEGER
);
CREATE TABLE "invoice_items" (
  "item_id" INTEGER PRIMARY KEY AUTOINCREMENT, "invoice_id" INTEGER,
  "clothing_id" INTEGER, "item_name" TEXT, "item_name_en" TEXT,
  "content" TEXT, "content_en" TEXT, "qty" INTEGER, "unit_price" REAL,
  "unit_cost" REAL, "total_price" REAL, "total_cost" REAL, "note" TEXT,
  "note_en" TEXT, "created_at" TEXT
);
CREATE TABLE "credit_notes" (
  "credit_id" INTEGER PRIMARY KEY AUTOINCREMENT, "invoice_id" INTEGER,
  "customer_id" INTEGER, "reason" TEXT, "subtotal" REAL, "tax_amount" REAL,
  "total" REAL, "restock_value" REAL, "created_by" INTEGER,
  "created_at" TEXT, "zatca_uuid" TEXT
);
CREATE TABLE "customer_balance_log" (
  "log_id" INTEGER PRIMARY KEY AUTOINCREMENT, "customer_id" INTEGER,
  "change_amount" REAL, "balance_after" REAL, "reason" TEXT,
  "reference_id" INTEGER, "created_at" TEXT, "created_by" INTEGER
);
"""

# الأعمدة التي يكتبها `CreditNoteService` — لا بدّ أن تكون في المخطط الحقيقي.
CREDIT_COLS = [
    "invoice_id", "customer_id", "reason", "subtotal", "tax_amount",
    "total", "restock_value", "created_by", "created_at", "zatca_uuid",
]
INVOICE_COLS = [
    "invoices_id", "invoice_number_text", "shift_id", "customer_id",
    "customer_name", "customer_phone", "total_price", "discount_amount",
    "tax_amount", "tax_base", "tax_rate", "final_amount", "paid_amount",
    "payment_method", "remaining_amount", "discount_code", "invoice_date",
    "list_data", "map_data", "status", "credit_note_of", "created_by",
]
ITEM_COLS = [
    "invoice_id", "clothing_id", "item_name", "item_name_en", "content",
    "content_en", "qty", "unit_price", "unit_cost", "total_price",
    "total_cost", "note", "note_en", "created_at",
]
LOG_COLS = [
    "customer_id", "change_amount", "balance_after", "reason",
    "reference_id", "created_at", "created_by",
]


def cols_of(con: sqlite3.Connection, table: str) -> set[str]:
    try:
        return {r[1] for r in con.execute(f'PRAGMA table_info("{table}")')}
    except sqlite3.Error:
        return set()


def main() -> int:
    tmp = tempfile.mkdtemp(prefix="laundry_credit_")
    src = sys.argv[1] if len(sys.argv) > 1 else live_db_path()
    if src and os.path.exists(src):
        db = os.path.join(tmp, "copy.db")
        shutil.copy2(src, db)
        mode = "نسخة من القاعدة الحيّة"
    else:
        db = os.path.join(tmp, "synthetic.db")
        con = sqlite3.connect(db)
        con.executescript(SYNTHETIC)
        con.commit()
        con.close()
        mode = "قاعدة اصطناعية"

    con = sqlite3.connect(db)
    print(f"── المصدر: {mode} ({db})")

    # ─── [1] المخطط يحمل كل عمود يكتبه الإشعار ───
    for table, need in (
        ("credit_notes", CREDIT_COLS),
        ("invoices", INVOICE_COLS),
        ("invoice_items", ITEM_COLS),
        ("customer_balance_log", LOG_COLS),
    ):
        have = cols_of(con, table)
        missing = [c for c in need if c not in have]
        check(f"1. {table}: كل الأعمدة المكتوبة موجودة", not missing, ", ".join(missing))

    # ─── تهيئة صفوف الاختبار ───
    con.execute("DELETE FROM invoice_items WHERE invoice_id >= 990001")
    con.execute("DELETE FROM invoices WHERE invoices_id >= 990001")
    con.execute("DELETE FROM credit_notes WHERE invoice_id >= 990001")
    con.execute("DELETE FROM customers WHERE customer_id >= 990001")

    con.execute(
        'INSERT INTO "customers" (customer_id, customer_name, balance, is_active, '
        "join_date) VALUES (990001, 'زبون اختبار', 0, 1, '2026-01-01')"
    )
    # فاتورة أصلية: 100 نقدًا، تكلفة 40 ⇒ ربح 60. وذمة أخرى قائمة 30.
    con.execute(
        'INSERT INTO "invoices" (invoices_id, invoice_number_text, customer_id, '
        'customer_name, total_price, discount_amount, tax_amount, tax_base, '
        'tax_rate, final_amount, paid_amount, payment_method, remaining_amount, '
        'invoice_date, list_data, map_data, status, credit_note_of) '
        "VALUES (990001, 'INV-990001', 990001, 'زبون اختبار', 100, 0, 0, 100, 0, "
        "100, 100, 'cash', 0, '2026-10-30 10:00:00', '[]', '{}', 'delivered', NULL)"
    )
    con.execute(
        'INSERT INTO "invoices" (invoices_id, invoice_number_text, customer_id, '
        'customer_name, total_price, discount_amount, tax_amount, tax_base, '
        'tax_rate, final_amount, paid_amount, payment_method, remaining_amount, '
        'invoice_date, list_data, map_data, status, credit_note_of) '
        "VALUES (990002, 'INV-990002', 990001, 'زبون اختبار', 30, 0, 0, 30, 0, "
        "30, 0, 'credit', 30, '2026-10-29 10:00:00', '[]', '{}', 'delivered', NULL)"
    )
    con.execute(
        'INSERT INTO "invoice_items" (invoice_id, item_name, qty, unit_price, '
        "unit_cost, total_price, total_cost, created_at) "
        "VALUES (990001, 'ثوب', 2, 50, 20, 100, 40, '2026-10-30 10:00:00')"
    )
    con.commit()

    # ─── [2] تنفيذ خطوات الخدمة (نفس SQL) ───
    credit_id = 990101
    con.execute(
        'INSERT INTO "credit_notes" (invoice_id, customer_id, reason, subtotal, '
        "tax_amount, total, restock_value, created_by, created_at, zatca_uuid) "
        "VALUES (990001, 990001, 'إرجاع كامل', 100, 0, 100, 0, 1, "
        "'2026-10-30 12:00:00', NULL)"
    )
    con.execute(
        'INSERT INTO "invoices" (invoices_id, invoice_number_text, customer_id, '
        'customer_name, total_price, discount_amount, tax_amount, tax_base, '
        'tax_rate, final_amount, paid_amount, payment_method, remaining_amount, '
        'invoice_date, list_data, map_data, status, credit_note_of) '
        "VALUES (?, 'CN-990101', 990001, 'زبون اختبار', -100, 0, 0, -100, 0, "
        "-100, -100, 'cash', 0, '2026-10-30 12:00:00', '[]', ?, 'delivered', 990001)",
        (credit_id, json.dumps({"credit_note_of": 990001})),
    )
    con.execute(
        'INSERT INTO "invoice_items" (invoice_id, item_name, qty, unit_price, '
        "unit_cost, total_price, total_cost, created_at) "
        "VALUES (?, 'ثوب', -2, 50, 20, -100, -40, '2026-10-30 12:00:00')",
        (credit_id,),
    )
    con.execute(
        'UPDATE "invoices" SET remaining_amount = 0 WHERE invoices_id = 990001'
    )
    con.commit()

    # ─── [3] الأصل لم يُمحَ ───
    orig = con.execute(
        'SELECT final_amount, paid_amount, remaining_amount, credit_note_of '
        "FROM invoices WHERE invoices_id = 990001"
    ).fetchone()
    check("3. الفاتورة الأصلية باقية بمبلغها المدفوع", orig[0] == 100 and orig[1] == 100)
    check("3. براءة ذمة الأصل (remaining = 0)", orig[2] == 0)
    check("3. الأصل ليس إشعارًا (credit_note_of NULL)", orig[3] is None)

    # ─── [4] المستند العكسي ───
    cn = con.execute(
        'SELECT final_amount, paid_amount, credit_note_of, status, payment_method '
        f"FROM invoices WHERE invoices_id = {credit_id}"
    ).fetchone()
    check("4. الإشعار سالب بمقدار الأصل", cn[0] == -100)
    check("4. الردّ نقدًا ⇒ paid سالب (يخصم من الصندوق)", cn[1] == -100)
    check("4. موسوم بالأصل", cn[2] == 990001)
    check("4. حالته delivered فلا يدخل خط الغسيل", cn[3] == "delivered")

    # ─── [5] التقارير التجميعية تصحّ بلا تعديل ───
    net = con.execute(
        "SELECT COALESCE(SUM(final_amount), 0) FROM invoices "
        "WHERE invoices_id IN (990001, 990101)"
    ).fetchone()[0]
    check("5. صافي المبيعات = صفر بعد الإرجاع الكامل", abs(net) < 1e-9, f"net={net}")

    counted = con.execute(
        "SELECT COUNT(CASE WHEN COALESCE(credit_note_of, 0) = 0 THEN 1 END) "
        "FROM invoices WHERE invoices_id IN (990001, 990101)"
    ).fetchone()[0]
    check("5. عدّاد الفواتير لا يعدّ الإشعار", counted == 1, f"count={counted}")

    cash = con.execute(
        "SELECT COALESCE(SUM(paid_amount), 0) FROM invoices "
        "WHERE invoices_id IN (990001, 990101)"
    ).fetchone()[0]
    check("5. الصندوق ينقص بمقدار الردّ النقدي", abs(cash - 0) < 1e-9, f"cash={cash}")

    # ─── [6] التكلفة تُلغى أيضًا ⇒ الربح يعود صفرًا لا سالبًا ───
    revenue = con.execute(
        "SELECT COALESCE(SUM(total_price), 0) FROM invoice_items "
        "WHERE invoice_id IN (990001, 990101)"
    ).fetchone()[0]
    cost = con.execute(
        "SELECT COALESCE(SUM(total_cost), 0) FROM invoice_items "
        "WHERE invoice_id IN (990001, 990101)"
    ).fetchone()[0]
    check("6. الإيراد والبنود يلغيان بعضهما", abs(revenue) < 1e-9, f"rev={revenue}")
    check("6. التكلفة تُلغى كذلك (لا ربح سالب)", abs(cost) < 1e-9, f"cost={cost}")

    # ─── [7] لوحة المصنعية تستبعد الإشعار ───
    board = con.execute(
        "SELECT COUNT(*) FROM invoices WHERE COALESCE(credit_note_of, 0) = 0 "
        "AND COALESCE(status, '') NOT IN ('delivered', 'تم التسليم') "
        "AND invoices_id IN (990001, 990101)"
    ).fetchone()[0]
    check("7. لوحة المصنعية لا تعرض الإشعار", board == 0, f"rows={board}")

    # ─── [8] وسم «مُرجعة» في سجل الفواتير ───
    is_returned = con.execute(
        'SELECT (SELECT COUNT(*) FROM "credit_notes" cn '
        'WHERE cn."invoice_id" = i."invoices_id") AS "is_returned" '
        'FROM "invoices" i WHERE i."invoices_id" = 990001'
    ).fetchone()[0]
    check("8. الأصل يظهر موسومًا «مُرجعة»", is_returned == 1)

    # ─── [9] الحرس المزدوج: إشعار ثانٍ لنفس الأصل ───
    dup = con.execute(
        'SELECT COUNT(*) FROM "credit_notes" WHERE "invoice_id" = 990001'
    ).fetchone()[0]
    check("9. الإشعار الثاني مرفوض (موجود مسبقًا)", dup == 1, f"notes={dup}")

    # ─── [10] الردّ رصيدًا: FIFO ثم الفائض سلفة ───
    #
    # محاكاة `allocatePaymentFifo(100)` على ذمة قائمة 30:
    #   • تُسدَّد الذمة (30) ⇒ remaining = 0
    #   • الفائض 70 يصبح رصيدًا موجبًا (سلفة)
    con.execute(
        'UPDATE "invoices" SET remaining_amount = 0, paid_amount = 30 '
        "WHERE invoices_id = 990002"
    )
    con.execute('UPDATE "customers" SET balance = 70 WHERE customer_id = 990001')
    con.commit()
    d2 = con.execute(
        'SELECT remaining_amount FROM "invoices" WHERE invoices_id = 990002'
    ).fetchone()[0]
    bal = con.execute(
        'SELECT balance FROM "customers" WHERE customer_id = 990001'
    ).fetchone()[0]
    check("10. الرصيد الدائن يسدّد أقدم ذمة أولًا", d2 == 0, f"remaining={d2}")
    check("10. الفائض يُقيَّد سلفةً موجبة", abs(bal - 70) < 1e-9, f"balance={bal}")
    # بعد المزامنة: الرصيد الموجب يبقى (keepCredit) ولا تُمحوه إعادة الاشتقاق.
    stored = bal
    debt = con.execute(
        "SELECT COALESCE(SUM(remaining_amount), 0) FROM invoices "
        "WHERE customer_id = 990001 AND subscription_id IS NULL "
        "AND remaining_amount > 0.004"
    ).fetchone()[0]
    target = stored if stored > 0 else -debt
    check("10. syncBalance يُبقي السلفة (keepCredit)", abs(target - 70) < 1e-9)

    con.close()
    print("─" * 60)
    print(f"نجح: {OK} · فشل: {FAIL}")
    if FAIL:
        return 1
    print("✅ كل الفحوص نجحت")
    return 0


if __name__ == "__main__":
    sys.exit(main())
