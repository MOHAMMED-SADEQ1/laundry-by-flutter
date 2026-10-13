"""تحقّق من وضعَي عرض الصندوق: «بالتاريخ» و«بالوردية».

يثبت — باختبار فعلي على SQLite — أن:
  1. وضع «بالوردية» يفلتر بـ`shift_id` حصرًا (لا بالتخمين الزمني).
  2. حركة سُجّلت **بعد** إقفال الوردية لكنها منسوبة إليها بـ`shift_id`
     تظهر في وضعها (وهذا هو الفرق الجوهري عن الفلترة الزمنية).
  3. حركة في وردية أخرى لا تتسرّب إلى وضع الوردية.
  4. 🚨 **تاريخ الصندوق = تاريخ فتح الوردية**: وردية تُفتح 23:30 وتُغلق
     03:00 اليوم التالي، وفاتورتها 00:30 ⇒ تُحتسب في صندوق يوم **الفتح**،
     لا في يوم تاريخ الفاتورة. (الخلق الذي كان في `DATE(invoice_date)`.)
  5. وضع «بالتاريخ» يشمل الورديات **المفتوحة** أيضًا (يوم العمل جارٍ).
  6. الصفوف غير المنسوبة (`shift_id IS NULL`) تبقى ظاهرة بتاريخ حركتها
     ولا تُحتسب مرتين (المنسوبة مستثناة من فرع الـNULL).
  7. رصيد افتتاح يوم العمل = افتتاح **أول** وردية (لا جمع افتتاحيات).
  8. إثبات عيب `DATE(x,'localtime')` على طابع محلي (تحويل مزدوج).

الاستعلامات منسوخة حرفيًا (بصيغة مكافئة) من
`lib/controller/daily_cash_controller.dart`.
"""

import sqlite3
import time

results = []


def check(name, got, expected):
    ok = got == expected
    results.append(ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}\n        got={got!r} expected={expected!r}")


SCHEMA = """
CREATE TABLE shifts (
  shift_id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_time TEXT NOT NULL, end_time TEXT,
  total_cash REAL DEFAULT 0, opening_balance REAL DEFAULT 0,
  counted_cash REAL, cash_difference REAL
);
CREATE TABLE invoices (
  invoices_id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_date TEXT, paid_amount REAL, payment_method TEXT,
  shift_id INTEGER, subscription_id INTEGER
);
CREATE TABLE customer_payments (
  payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_date TEXT, amount REAL, shift_id INTEGER, source TEXT
);
CREATE TABLE subscription_payments (
  payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  paid_date TEXT, amount REAL, shift_id INTEGER, source TEXT, method TEXT
);
CREATE TABLE expenses (
  expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT, amount REAL, shift_id INTEGER, payment_method TEXT
);
"""

# ── الورديات ──
# #1: 17/09 08:00→16:00 · #2: 17/09 16:30→23:00 (نفس اليوم)
# #3: 17/09 23:30 → 18/09 03:00  ← **يتجاوز منتصف الليل** (يوم الصندوق = 17)
# #4: 17/09 23:50 → NULL        ← مفتوحة (يوم الصندوق = 17)
SHIFTS = [
    ("2026-09-17T08:00:00.000", "2026-09-17T16:00:00.000", 5000.0, 1000.0),
    ("2026-09-17T16:30:00.000", "2026-09-17T23:00:00.000", 7300.0, 5000.0),
    ("2026-09-17T23:30:00.000", "2026-09-18T03:00:00.000", 200.0, 0.0),
    ("2026-09-17T23:50:00.000", None, 0.0, 0.0),
]
INVOICES = [
    ("2026-09-17T09:00:00.000", 300.0, "كاش", 1, None),
    ("2026-09-17T18:00:00.000", 450.0, "كاش", 2, None),
    ("2026-09-17T23:40:00.000", 120.0, "كاش", 2, None),  # بعد الإقفال، منسوبة
    ("2026-09-17T18:10:00.000", 900.0, "شبكة", 2, None),  # ليست كاش
    ("2026-09-17T19:00:00.000", 700.0, "كاش", 2, 9),  # فاتورة اشتراك
    ("2026-09-18T00:30:00.000", 200.0, "كاش", 3, None),  # بعد منتصف الليل
    ("2026-09-18T00:10:00.000", 60.0, "كاش", 4, None),  # وردية مفتوحة
]
EXPENSES = [
    ("2026-09-17T10:00:00.000", 200.0, 1, "كاش"),
    ("2026-09-17T20:00:00.000", 350.0, 2, "كاش"),
    ("2026-09-17T22:30:00.000", 90.0, 2, "كاش"),  # داخل النافذة التي يزيحها 'localtime'
    ("2026-09-18T01:00:00.000", 50.0, 3, "كاش"),  # بعد منتصف الليل
    ("2026-09-17T12:00:00.000", 30.0, None, "كاش"),  # غير منسوبة (بلا وردية)
]
DEBT_PAYS = [("2026-09-17T21:00:00.000", 150.0, 2, "manual")]


def build():
    c = sqlite3.connect(":memory:")
    c.executescript(SCHEMA)
    c.executemany("INSERT INTO shifts (start_time,end_time,total_cash,opening_balance) VALUES (?,?,?,?)", SHIFTS)
    c.executemany("INSERT INTO invoices (invoice_date,paid_amount,payment_method,shift_id,subscription_id) VALUES (?,?,?,?,?)", INVOICES)
    c.executemany("INSERT INTO expenses (date,amount,shift_id,payment_method) VALUES (?,?,?,?)", EXPENSES)
    c.executemany("INSERT INTO customer_payments (payment_date,amount,shift_id,source) VALUES (?,?,?,?)", DEBT_PAYS)
    return c


# ── استعلامات وضع «بالوردية» (shift_id = ?) ──
Q_SHIFT_INV = ("SELECT COALESCE(SUM(paid_amount),0) FROM invoices "
               "WHERE shift_id = ? AND payment_method = ? AND subscription_id IS NULL")
Q_SHIFT_EXP = ("SELECT COALESCE(SUM(amount),0) FROM expenses WHERE shift_id = ?")
Q_SHIFT_DEBT = ("SELECT COALESCE(SUM(amount),0) FROM customer_payments WHERE shift_id = ?")

# ── وضع «بالتاريخ»: ورديات فُتحت في ذلك التاريخ ثم حركاتها بـshift_id ──
# مكافئ لشرط `shift_id IN (…)` الذي يبنيه المتحكم + فرع الصفوف غير المنسوبة.
Q_DATE_INV = ("SELECT COALESCE(SUM(paid_amount),0) FROM invoices "
              "WHERE (shift_id IN (SELECT shift_id FROM shifts WHERE DATE(start_time) = ?) "
              "       OR (shift_id IS NULL AND DATE(invoice_date) = ?)) "
              "  AND payment_method = ? AND subscription_id IS NULL")
Q_DATE_EXP = ("SELECT COALESCE(SUM(amount),0) FROM expenses "
              "WHERE (shift_id IN (SELECT shift_id FROM shifts WHERE DATE(start_time) = ?) "
              "       OR (shift_id IS NULL AND DATE(date) = ?))")
Q_DATE_DEBT = ("SELECT COALESCE(SUM(amount),0) FROM customer_payments "
               "WHERE (shift_id IN (SELECT shift_id FROM shifts WHERE DATE(start_time) = ?) "
               "       OR (shift_id IS NULL AND DATE(payment_date) = ?))")

# ── الطريقة القديمة (تاريخ الحركة) — للتباين فقط ──
Q_DATE_INV_OLD = ("SELECT COALESCE(SUM(paid_amount),0) FROM invoices "
                  "WHERE DATE(invoice_date) = ? AND payment_method = ? AND subscription_id IS NULL")
Q_DATE_EXP_BUG = "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE DATE(date, 'localtime') = ?"


def one(c, sql, args=()):
    return c.execute(sql, args).fetchone()[0]


def main():
    c = build()
    d17 = "2026-09-17"
    d18 = "2026-09-18"

    # ── 1/2/3: وضع الوردية رقم 2 ──
    s2_inv = one(c, Q_SHIFT_INV, (2, "كاش"))
    check("وضع الوردية #2: فواتير كاش (تشمل حركة بعد الإقفال منسوبة إليها)",
          s2_inv, 450.0 + 120.0)
    check("وضع الوردية #2: مصروفات (350+90 المتأخر)", one(c, Q_SHIFT_EXP, (2,)), 440.0)
    check("وضع الوردية #2: سداد ذمم", one(c, Q_SHIFT_DEBT, (2,)), 150.0)
    check("وضع الوردية #2: لا تتسرّب فاتورة الوردية #1",
          one(c, Q_SHIFT_INV, (1, "كاش")), 300.0)

    # ── الوردية المتجاوزة لمنتصف الليل: حركاتها (18/09) تنتمي لورديتها ──
    check("وضع الوردية #3: فاتورة 00:30 (تاريخها 18/09)",
          one(c, Q_SHIFT_INV, (3, "كاش")), 200.0)
    check("وضع الوردية #3: مصروف 01:00", one(c, Q_SHIFT_EXP, (3,)), 50.0)

    # ── 4/5/6: وضع التاريخ ليوم 17/09 (يوم فتح الورديات) ──
    check("وضع التاريخ 17/09: كل فواتير كاش (300+450+120 من #1/#2 + 200 من #3 + 60 من #4 المفتوحة)",
          one(c, Q_DATE_INV, (d17, d17, "كاش")), 300.0 + 450.0 + 120.0 + 200.0 + 60.0)
    check("وضع التاريخ 17/09: كل المصروفات (200+350+90+50 المتأخر + 30 غير منسوبة)",
          one(c, Q_DATE_EXP, (d17, d17)), 200.0 + 350.0 + 90.0 + 50.0 + 30.0)
    check("وضع التاريخ 17/09: سداد الذمم", one(c, Q_DATE_DEBT, (d17, d17)), 150.0)

    # ── إثبات الإصلاح: الطريقة القديمة تُسقط فواتير ما بعد منتصف الليل ──
    check("🐞 الطريقة القديمة (DATE(invoice_date)) تُسقط 260 من صندوق يوم الفتح",
          one(c, Q_DATE_INV_OLD, (d17, "كاش")), 870.0)
    check("✅ الطريقة الجديدة تضمّها (الفرق = 260)",
          one(c, Q_DATE_INV, (d17, d17, "كاش")) - one(c, Q_DATE_INV_OLD, (d17, "كاش")), 260.0)
    check("✅ يوم 18/09 لا يحمل حركات ورديات فُتحت في 17/09 (لا وردية فُتحت فيه)",
          one(c, Q_DATE_INV, (d18, d18, "كاش")), 0.0)
    check("🐞 بينما القديم يُحمّلها على يوم 18 مزيّفةً (200 من #3 + 60 من #4)",
          one(c, Q_DATE_INV_OLD, (d18, "كاش")), 260.0)

    # ── الوضعان مختلفان فعليًا ⇒ المفتاح ليس تجميليًا ──
    check("الوضعان يختلفان: وردية#2 (570) ≠ اليوم (1130)",
          s2_inv != one(c, Q_DATE_INV, (d17, d17, "كاش")), True)

    # ── 7: رصيد افتتاح يوم العمل = افتتاح أول وردية ──
    first_id = c.execute(
        "SELECT shift_id FROM shifts WHERE DATE(start_time) = ? ORDER BY shift_id ASC LIMIT 1",
        (d17,),
    ).fetchone()[0]
    ob_first = one(c, "SELECT COALESCE(opening_balance,0) FROM shifts WHERE shift_id = ?", (first_id,))
    check("رصيد افتتاح يوم 17 = افتتاح أول وردية (المخزَّن 1000، لا 5000 المرحّل)",
          ob_first, 1000.0)
    # لو جُمعت الافتتاحيات لظهر رقم مختلف:
    summed = c.execute("SELECT COALESCE(SUM(opening_balance),0) FROM shifts WHERE DATE(start_time) = ?", (d17,)).fetchone()[0]
    check("جمع الافتتاحيات خطأ (1000 ≠ مجموعها)", ob_first != summed, True)

    # ── الفرق بين «بلا جرد» و«طابق» ──
    check("وردية بلا جرد: counted_cash = NULL (لا صفر)",
          c.execute("SELECT counted_cash FROM shifts WHERE shift_id = 3").fetchone()[0], None)

    # ── 8: إثبات عيب 'localtime' على طابع محلي ──
    offset_h = -time.timezone // 3600
    bug = one(c, Q_DATE_EXP_BUG, (d17,))
    check(f"عيب 'localtime' (إزاحة الجهاز {offset_h:+d}h): يُنقص مصروف 22:30 من اليوم",
          bug < one(c, Q_DATE_EXP, (d17, d17)), True)
    shifted = c.execute("SELECT DATE(?, 'localtime')", ("2026-09-17T22:30:00.000",)).fetchone()[0]
    check("مصروف 22:30 يوم 17 يُحتسب خطأً في يوم 18", shifted, "2026-09-18")

    print(f"\n{sum(results)}/{len(results)} نجحت")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
