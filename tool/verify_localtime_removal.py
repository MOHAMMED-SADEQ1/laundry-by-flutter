"""قياس أثر `DATE(x, 'localtime')` على التقارير — إثبات عددي قبل/بعد الإصلاح.

**الخلل:** كل طوابع المشروع تُكتب محلية (`DateTime.now().toIso8601String()`
بلا `toUtc()` في أي موضع). وSQLite تفترض أن نص الطابع **UTC**، فتُطبّق
`'localtime'` تحويلًا ثانيًا يزيح اليوم بمقدار إزاحة الجهاز. على UTC+3 يقع
حدّ الانقلاب عند **21:00 محليًا**: كل فاتورة/مصروف بعدها يُنسب لليوم التالي.

**التمييز الحاسم:** الإصلاح **غير متماثل**:
  - `DATE(عمود, 'localtime')`  ← خطأ (العمود محلي أصلًا) ⇒ تُحذف.
  - `DATE('now', 'localtime')` ← **صحيحة** (`'now'` في SQLite UTC فعلًا)
                                 ⇒ تبقى كما هي.

الاستعلامات منسوخة حرفيًا من المشروع (الصيغة القديمة والجديدة) حتى يفشل
الاختبار فعلًا إن عاد أحد إلى النمط الممنوع.
"""

import sqlite3
import time

results = []


def check(name, got, expected):
    ok = got == expected
    results.append(ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}\n        got={got!r} expected={expected!r}")


SCHEMA = """
CREATE TABLE invoices (
  invoices_id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_date TEXT, final_amount REAL, total_price REAL, paid_amount REAL,
  list_data TEXT, subscription_id INTEGER
);
CREATE TABLE expenses (
  expense_id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT, date TEXT, amount REAL
);
CREATE TABLE audit_log (
  log_id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, timestamp TEXT, table_name TEXT
);
CREATE TABLE subscriptions (
  subscription_id INTEGER PRIMARY KEY AUTOINCREMENT,
  paid_until_date TEXT, is_active INTEGER DEFAULT 1, status TEXT
);
"""

# اليوم المحلي المرجعي: 2026-09-19 (جهاز UTC+3 ⇒ الانقلاب عند 21:00)
D = "2026-09-19"
INVOICES = [
    # نهارًا: لا يتأثر بأي الحالتين
    (f"{D}T10:00:00.000", 100.0, None),
    # مساءً: يتأثر — يُنسب لليوم التالي في الصيغة القديمة
    (f"{D}T22:30:00.000", 200.0, None),
    # آخر يوم في الشهر مساءً: يقفز إلى الشهر التالي
    ("2026-09-30T22:30:00.000", 500.0, None),
]
EXPENSES = [(f"{D}T22:00:00.000", 100.0)]
AUDIT = [(f"{D}T22:00:00.000",)]
SUBS = [("2026-09-18T22:30:00.000",)]  # انتهى أمس مساءً


def build():
    c = sqlite3.connect(":memory:")
    c.executescript(SCHEMA)
    c.executemany(
        "INSERT INTO invoices (invoice_date, final_amount, subscription_id) VALUES (?,?,?)",
        INVOICES,
    )
    c.executemany("INSERT INTO expenses (date, amount) VALUES (?,?)", EXPENSES)
    c.executemany("INSERT INTO audit_log (timestamp, action) VALUES (?, 'shift_close')", AUDIT)
    c.executemany("INSERT INTO subscriptions (paid_until_date) VALUES (?)", SUBS)
    return c


def one(c, sql, args=()):
    return c.execute(sql, args).fetchone()[0]


def main():
    c = build()
    offset = -time.timezone // 3600
    print(f"إزاحة جهاز التشغيل عن UTC: {offset:+d} ساعة "
          f"(الانقلاب المتوقع عند {24 - offset}:00 محليًا)\n")

    # ── 1. مبيعات اليوم (dashboard: _loadTodaySales) ──
    old = one(c, "SELECT COALESCE(SUM(final_amount),0) FROM invoices "
                 "WHERE DATE(invoice_date, 'localtime') = ? AND subscription_id IS NULL", (D,))
    new = one(c, "SELECT COALESCE(SUM(final_amount),0) FROM invoices "
                 "WHERE DATE(invoice_date) = ? AND subscription_id IS NULL", (D,))
    check("مبيعات اليوم: الصيغة القديمة تُسقط فاتورة المساء", old, 100.0)
    check("مبيعات اليوم: الصحيحة 100 + 200", new, 300.0)

    # ── 2. تكلفة اليوم (dashboard: _loadTodayCost) — كانت بلا localtime أصلاً ──
    cost_rows = one(c, "SELECT COUNT(*) FROM invoices WHERE DATE(invoice_date) = ? "
                       "AND subscription_id IS NULL", (D,))
    check("تكلفة اليوم تمسح صفّين بينما الإيراد صفٌّ واحد ⇒ ربح مخلوط الأساسين",
          (cost_rows, one(c, "SELECT COUNT(*) FROM invoices "
                             "WHERE DATE(invoice_date, 'localtime') = ? AND subscription_id IS NULL", (D,))),
          (2, 1))

    # ── 3. تجميع الرسم الأسبوعي (dashboard: _loadWeeklySales) ──
    old_buckets = dict(c.execute(
        "SELECT DATE(invoice_date, 'localtime') AS day, SUM(final_amount) "
        "FROM invoices WHERE subscription_id IS NULL GROUP BY day ORDER BY day").fetchall())
    new_buckets = dict(c.execute(
        "SELECT DATE(invoice_date) AS day, SUM(final_amount) "
        "FROM invoices WHERE subscription_id IS NULL GROUP BY day ORDER BY day").fetchall())
    check("التجميع اليومي: القديم يُنشئ يومًا وهميًا 2026-09-20", "2026-09-20" in old_buckets, True)
    check("التجميع اليومي الصحيح: لا يوم وهمي", "2026-09-20" in new_buckets, False)
    check("التجميع اليومي الصحيح: يوم 19 = 300", new_buckets[D], 300.0)

    # ── 4. تجميع الشهر (dashboard: _loadMonthlySales) — تسرّب بين الأشهر ──
    old_months = dict(c.execute(
        "SELECT strftime('%Y-%m', invoice_date, 'localtime') AS m, SUM(final_amount) "
        "FROM invoices WHERE subscription_id IS NULL GROUP BY m ORDER BY m").fetchall())
    new_months = dict(c.execute(
        "SELECT strftime('%Y-%m', invoice_date) AS m, SUM(final_amount) "
        "FROM invoices WHERE subscription_id IS NULL GROUP BY m ORDER BY m").fetchall())
    check("إيراد سبتمبر: القديم يسرّب 500 إلى أكتوبر", old_months.get("2026-09"), 100.0 + 200.0)
    check("إيراد سبتمبر الصحيح", new_months.get("2026-09"), 800.0)
    check("أكتوبر: القديم يُظهر إيرادًا لا يخصّه", old_months.get("2026-10"), 500.0)
    check("أكتوبر الصحيح: لا إيراد", new_months.get("2026-10"), None)

    # ── 5. مصروفات التقرير (report_controller: _expensesFor) ──
    old_exp = one(c, "SELECT COALESCE(SUM(amount),0) FROM expenses "
                     "WHERE DATE(date, 'localtime') >= ? AND DATE(date, 'localtime') <= ?", (D, D))
    new_exp = one(c, "SELECT COALESCE(SUM(amount),0) FROM expenses "
                     "WHERE DATE(date) >= ? AND DATE(date) <= ?", (D, D))
    check("مصروفات التقرير: القديم يُسقط مصروف 22:00 من يومه", old_exp, 0.0)
    check("مصروفات التقرير الصحيحة", new_exp, 100.0)

    # ── 6. شاشة المصروفات (expense_service.list) — يجب أن تُصحّح مع التقرير ──
    old_screen = one(c, "SELECT COALESCE(SUM(amount),0) FROM expenses "
                        "WHERE DATE(date, 'localtime') >= ? AND DATE(date, 'localtime') <= ?", (D, D))
    new_screen = one(c, "SELECT COALESCE(SUM(amount),0) FROM expenses "
                        "WHERE DATE(date) >= ? AND DATE(date) <= ?", (D, D))
    check("كانا (الشاشة والتقرير) متطابقين في الخطأ", old_screen == old_exp, True)
    check("وبعد الإصلاح يبقى التطابق — في الصواب", new_screen == new_exp, True)

    # ── 7. سجل التدقيق (audit_service) ──
    old_audit = one(c, "SELECT COUNT(*) FROM audit_log "
                       "WHERE DATE(timestamp, 'localtime') >= ? AND DATE(timestamp, 'localtime') <= ?", (D, D))
    new_audit = one(c, "SELECT COUNT(*) FROM audit_log "
                       "WHERE DATE(timestamp) >= ? AND DATE(timestamp) <= ?", (D, D))
    check("سجل التدقيق: حدث 22:00 يختفي من فلتر «اليوم»", old_audit, 0)
    check("سجل التدقيق الصحيح: يظهر", new_audit, 1)

    # ── 8. تصنيف الاشتراك المنتهي (sqldb.1079) ──
    # حالة واضحة (المقارنة بيوم متأخر) ⇒ لا فرق بين الصيغتين.
    later = "2026-09-20"
    old_status = one(c, "SELECT CASE WHEN DATE(paid_until_date, 'localtime') "
                              "< DATE(?) THEN 'overdue' ELSE 'active' END "
                              "FROM subscriptions", (later,))
    new_status = one(c, "SELECT CASE WHEN DATE(paid_until_date) "
                              "< DATE(?) THEN 'overdue' ELSE 'active' END "
                              "FROM subscriptions", (later,))
    check("المقارنة بيوم لاحق ⇒ الحالتان تتفقان (لا فرق)",
          (old_status, new_status), ("overdue", "overdue"))
    # لكن عند حدّ اليوم نفسه يتغيّر التصنيف:
    old_same = one(c, "SELECT CASE WHEN DATE(paid_until_date, 'localtime') "
                              "< DATE(?) THEN 'overdue' ELSE 'active' END "
                              "FROM subscriptions", ("2026-09-19",))
    new_same = one(c, "SELECT CASE WHEN DATE(paid_until_date) "
                              "< DATE(?) THEN 'overdue' ELSE 'active' END "
                              "FROM subscriptions", ("2026-09-19",))
    check("يُمدّد الاشتراك يومًا مزيّفًا بسبب الإزاحة", (old_same, new_same), ("active", "overdue"))

    # ── 9. `'now'` UTC فعلًا ⇒ لا تُحذف localtime عنه ──
    utc_instant = "2026-09-18 21:30:00"
    check("DATE('now'…) بلا localtime يتأخر يومًا كاملًا في آخر 3 ساعات",
          (one(c, "SELECT DATE(?)", (utc_instant,)),
           one(c, "SELECT DATE(?, 'localtime')", (utc_instant,))),
          ("2026-09-18", "2026-09-19"))

    print(f"\n{sum(results)}/{len(results)} نجحت")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
