#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات **تقييد كشف الحساب بفترة** (CustomerStatementService.build) على SQLite حقيقي.

يُشغّل نفس استعلامات الخدمة مع شرط الفترة المُولَّد بنفس منطق Dart:
  fromIso = DateTime(y,m,d).toIso8601String()            (بداية اليوم — شامل)
  toIso   = DateTime(y,m,d)+1day → toIso8601String()      (حصري ⇒ يشمل يوم النهاية)

ويُثبت أن:
  • القوائم (فواتير/بنود/دفعات/استهلاك) تُقيَّد بالفترة.
  • **الذمة لا تُقيَّد** — رصيد لحظي لا تدفّق.
  • الحدّان **شاملان** (فاتورة 23:59 من يوم النهاية تُحتسب).

ويُدقّق الكود نصيًا (بلا Flutter) على مواضع الاستخدام في الخدمة/المتحكّم/الـPDF.
"""
import json
import os
import re
import sqlite3
import sys

PASS = 0
FAIL = 0
HERE = os.path.dirname(os.path.abspath(__file__))


def ok(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS  {label}{(': ' + str(detail)) if detail else ''}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}{(': ' + str(detail)) if detail else ''}")


def check(label, got, want):
    ok(f"{label} = {want!r}", got == want, f"got {got!r}" if got != want else '')


def strip_line_comments(src):
    return '\n'.join(
        (line if line.find('//') < 0 else line[:line.find('//')])
        for line in src.splitlines()
    )


def picker_calls(src):
    """يستخرج نصّ كل نداء `showDatePicker`/`showDateRangePicker` بأقواس متوازنة.

    الغرض: التحقّق من وسائط النداء نفسها (هل مرّر `locale:`؟) لا من مجرّد وجود
    الكلمة في الملف — فالفحص النصّي الساذج يخلط بين منتقي التاريخ وبين
    `MaterialApp.locale` الذي يمرّ عبر `LocalizationsResolver` ويُحسم بأمان
    مقابل `supportedLocales`.
    """
    out = []
    for m in re.finditer(r'show(DatePicker|DateRangePicker)\s*\(', src):
        i, depth = m.end(), 1
        while i < len(src) and depth:
            if src[i] == '(':
                depth += 1
            elif src[i] == ')':
                depth -= 1
            i += 1
        out.append(src[m.start():i])
    return out


# ═══════════════════ قاعدة مصغّرة: 3 أشهر ═══════════════════

def build():
    db = sqlite3.connect(":memory:")
    db.executescript(
        """
        CREATE TABLE customers (customer_id INTEGER PRIMARY KEY,
          customer_name TEXT, phone_1 TEXT, phone_2 TEXT,
          balance REAL DEFAULT 0, is_active INTEGER DEFAULT 1);
        CREATE TABLE invoices (invoices_id INTEGER PRIMARY KEY,
          customer_id INTEGER, invoice_date TEXT, final_amount REAL,
          paid_amount REAL, remaining_amount REAL, payment_method TEXT,
          subscription_id INTEGER, list_data TEXT);
        CREATE TABLE customer_payments (payment_id INTEGER PRIMARY KEY,
          customer_id INTEGER, amount REAL, payment_method TEXT, source TEXT,
          notes TEXT, invoice_id INTEGER, payment_date TEXT,
          recorded_by INTEGER);
        CREATE TABLE users (user_id INTEGER PRIMARY KEY, full_name TEXT);
        CREATE TABLE subscription_coverage_log (log_id INTEGER PRIMARY KEY,
          subscription_id INTEGER, customer_id INTEGER, event TEXT,
          amount REAL, pieces INTEGER, coverage_from TEXT, coverage_to TEXT,
          reference_id INTEGER, notes TEXT, created_at TEXT,
          created_by INTEGER);
        """
    )
    db.execute("INSERT INTO customers VALUES (1,'أحمد','0500000000','',0,1)")

    def inv(iid, date, final, paid, remaining, items):
        db.execute(
            "INSERT INTO invoices VALUES (?,?,?,?,?,?,?,?,?)",
            (iid, 1, date, final, paid, remaining, 'آجل', None,
             json.dumps(items)),
        )

    def it(name, count, price):
        return {"vestments": name, "content": "غسيل", "count": count,
                "price": price, "total_price": count * price}

    # ─── سبتمبر ───
    inv(1, "2026-09-05T10:00:00.000", 100.0, 100.0, 0.0, [it("ثوب", 2, 50)])
    # ─── أكتوبر ───
    inv(2, "2026-10-01T00:00:00.000", 200.0, 50.0, 150.0, [it("بنطال", 2, 100)])
    inv(3, "2026-10-31T23:59:59.999", 300.0, 100.0, 200.0, [it("بطانية", 3, 100)])
    # ─── نوفمبر (خارج الفترة المختبرة) ───
    inv(4, "2026-11-01T00:00:00.000", 400.0, 0.0, 400.0, [it("ثوب", 8, 50)])

    db.execute("INSERT INTO users VALUES (7,'م')")
    # دفعات: سبتمبر · أكتوبر · نوفمبر
    db.execute("INSERT INTO customer_payments VALUES (1,1,100.0,'كاش','manual','',1,'2026-09-05T10:05:00.000',7)")
    db.execute("INSERT INTO customer_payments VALUES (2,1,150.0,'كاش','manual','',2,'2026-10-15T10:00:00.000',7)")
    db.execute("INSERT INTO customer_payments VALUES (3,1,400.0,'كاش','manual','',4,'2026-11-02T10:00:00.000',7)")
    # استهلاك اشتراك: أكتوبر · نوفمبر
    for i, (pcs, dt) in enumerate(
        [(5, "2026-10-10T09:00:00.000"), (7, "2026-11-10T09:00:00.000")], start=1
    ):
        db.execute(
            "INSERT INTO subscription_coverage_log VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (i, 1, 1, "usage", pcs * 10.0, pcs, "2026-10-01", "2026-10-31",
             2, "", dt, 7),
        )
    db.commit()
    return db


# ═══════ الاستعلامات — منقولة حرفيًا من الخدمة (مع شرط الفترة) ═══════

def and_range(col, from_iso, to_iso):
    """نفس دالة `andRange` في Dart."""
    return ((f' AND {col} >= ?' if from_iso else '')
            + (f' AND {col} < ?' if to_iso else ''))


def range_args(from_iso, to_iso):
    return [x for x in (from_iso, to_iso) if x is not None]


def iso(y, m, d):
    return f"{y:04d}-{m:02d}-{d:02d}T00:00:00.000"


def q_invoices(db, cid, f, t):
    return db.execute(
        "SELECT invoices_id, invoice_date, final_amount, paid_amount, "
        "  remaining_amount, payment_method, subscription_id "
        "FROM invoices WHERE customer_id = ? AND subscription_id IS NULL"
        + and_range('invoice_date', f, t) +
        " ORDER BY invoice_date ASC",
        [cid] + range_args(f, t),
    ).fetchall()


def q_items(db, cid, f, t):
    return db.execute(
        "SELECT i.invoices_id AS iid, "
        "  json_extract(j.value, '$.vestments') AS name, "
        "  CAST(json_extract(j.value, '$.count') AS INTEGER) AS qty, "
        "  CAST(json_extract(j.value, '$.total_price') AS REAL) AS val "
        "FROM invoices i, json_each(i.list_data) j "
        "WHERE i.customer_id = ? AND i.subscription_id IS NULL"
        + and_range('i.invoice_date', f, t) +
        " ORDER BY i.invoice_date ASC",
        [cid] + range_args(f, t),
    ).fetchall()


def q_payments(db, cid, f, t):
    return db.execute(
        "SELECT cp.payment_date, cp.amount, cp.payment_method, cp.source, "
        "  cp.notes, cp.invoice_id, COALESCE(u.full_name,'') AS user_name "
        "FROM customer_payments cp "
        "LEFT JOIN users u ON cp.recorded_by = u.user_id "
        "WHERE cp.customer_id = ?" + and_range('cp.payment_date', f, t) +
        " ORDER BY cp.payment_date ASC",
        [cid] + range_args(f, t),
    ).fetchall()


def q_usage(db, cid, f, t):
    return db.execute(
        "SELECT created_at, subscription_id, pieces, amount, reference_id "
        "FROM subscription_coverage_log "
        "WHERE customer_id = ? AND event = 'usage'"
        + and_range('created_at', f, t) +
        " ORDER BY created_at ASC",
        [cid] + range_args(f, t),
    ).fetchall()


def q_debt_now(db, cid):
    """مجموع الذمة **بلا** أي شرط فترة."""
    return db.execute(
        "SELECT COALESCE(SUM(remaining_amount), 0) AS debt FROM invoices "
        "WHERE customer_id = ? AND subscription_id IS NULL",
        [cid],
    ).fetchone()[0]


def main():
    db = build()
    cid = 1

    # ═══════════ [1] بلا فترة ⇒ كل شيء ═══════════
    print("\n[1] بلا فترة: لا تقييد")
    check("عدد الفواتير", len(q_invoices(db, cid, None, None)), 4)
    check("عدد بنود الأصناف", len(q_items(db, cid, None, None)), 4)
    check("عدد الدفعات", len(q_payments(db, cid, None, None)), 3)
    check("عدد سجلات الاستهلاك", len(q_usage(db, cid, None, None)), 2)

    # ═══════════ [2] أكتوبر كاملًا — الحدّان شاملان ═══════════
    print("\n[2] الفترة = أكتوبر كاملًا (حدّان شاملان)")
    f, t = iso(2026, 10, 1), iso(2026, 11, 1)
    inv = q_invoices(db, cid, f, t)
    ids = [r[0] for r in inv]
    check("الفواتير داخل الفترة (2 و3)", ids, [2, 3])
    ok("فاتورة أول يوم 00:00 دخلت (حدّ أدنى شامل)", 2 in ids)
    ok("فاتورة آخر يوم 23:59:59.999 دخلت (حدّ أعلى حاسم/حصري)",
       3 in ids, [r[1] for r in inv])
    ok("فاتورة 1 نوفمبر خرجت", 4 not in ids)

    print("\n[3] بنود الأصناف تُقيَّد مع الفترة")
    names = set(r[1] for r in q_items(db, cid, f, t))
    check("أصناف أكتوبر (مجموعة)", names, {'بنطال', 'بطانية'})
    ok("«ثوب» (سبتمبر ونوفمبر) خارج الفترة", 'ثوب' not in names)

    print("\n[4] الدفعات والاستهلاك يُقيَّدان")
    check("دفعات أكتوبر", [r[0][:10] for r in q_payments(db, cid, f, t)],
          ['2026-10-15'])
    check("استهلاك أكتوبر", [r[0][:10] for r in q_usage(db, cid, f, t)],
          ['2026-10-10'])

    print("\n[5] 🚨 الذمة **لا** تُقيَّد بالفترة (رصيد لحظي)")
    check("الذمة الكلية (150+200+400)", q_debt_now(db, cid), 750.0)
    period_debt = sum(r[4] for r in inv)
    check("ذمة فواتير الفترة وحدها (150+200)", period_debt, 350.0)
    ok("الذمة المعروضة ≠ ذمة الفترة (فلا تُخلط)",
       q_debt_now(db, cid) != period_debt,
       f"الكل={q_debt_now(db, cid)} · الفترة={period_debt}")

    print("\n[6] التدفّقات تُقيَّد والفروق حسابية")
    check("مشتريات أكتوبر (200+300)",
          sum(r[2] for r in inv), 500.0)
    check("مسدَّد أكتوبر (50+100)", sum(r[3] for r in inv), 150.0)
    check("قطع أكتوبر (2+3)", sum(r[2] for r in q_items(db, cid, f, t)), 5)

    # ═══════════ [7] يوم واحد · شهر كامل · حدّ واحد ═══════════
    print("\n[7] حالات أخرى")
    one = q_invoices(db, cid, iso(2026, 10, 31), iso(2026, 11, 1))
    check("يوم واحد (31 أكتوبر)", [r[0] for r in one], [3])
    only_from = q_invoices(db, cid, iso(2026, 10, 1), None)
    check("من تاريخ بلا نهاية ⇒ من أكتوبر فصاعدًا",
          [r[0] for r in only_from], [2, 3, 4])
    only_to = q_invoices(db, cid, None, iso(2026, 10, 1))
    check("حتى تاريخ بلا بداية ⇒ سبتمبر فقط",
          [r[0] for r in only_to], [1])

    # ═══════════ [8] تدقيق الكود نصيًا ═══════════
    print("\n[8] تدقيق الكود (بلا Flutter)")
    svc = strip_line_comments(
        open(os.path.join(HERE, '..', 'lib', 'services', 'customer',
                          'customer_statement_service.dart'),
             encoding='utf-8').read())
    ctrl = strip_line_comments(
        open(os.path.join(HERE, '..', 'lib', 'controller', 'customer',
                          'customer_statement_controller.dart'),
             encoding='utf-8').read())
    pdf = strip_line_comments(
        open(os.path.join(HERE, '..', 'lib', 'core', 'services',
                          'preparePDF.dart'), encoding='utf-8').read())
    sheet = strip_line_comments(
        open(os.path.join(HERE, '..', 'lib', 'view', 'widget', 'customer',
                          'customer_statement_sheet.dart'),
             encoding='utf-8').read())

    ok("build تقبل from/to اختياريين",
       'DateTime? from,' in svc and 'DateTime? to,' in svc)
    ok("الحد الأعلى حصري (+يوم واحد)",
       '.add(const Duration(days: 1)).toIso8601String()' in svc)
    for col in ['invoice_date', 'i.invoice_date', 'cp.payment_date', 'created_at']:
        ok(f"شرط الفترة على {col}", f"andRange('{col}')" in svc)
    # استعلام الذمة مكتوب على سطرين في المصدر ⇒ نفحص الجزأين.
    debt_seg = svc.split('AS debt')[1].split(';')[0] if 'AS debt' in svc else ''
    ok("🚨 استعلام الذمة مستقل (SUM على invoices)",
       'COALESCE(SUM(remaining_amount), 0) AS debt FROM invoices' in svc)
    ok("🚨 استعلام الذمة **بلا** شرط فترة",
       'andRange' not in debt_seg and 'FROM invoices' in debt_seg,
       debt_seg.strip()[:80])
    ok("totalDebt يقرأ debtNow", 'double get totalDebt => debtNow;' in svc)
    ok("hasRange مُعرَّفة", 'bool get hasRange =>' in svc)

    ok("المتحكّم يحفظ الفترة", 'Rxn<DateTimeRange> selectedRange' in ctrl)
    ok("setRange موجودة", 'void setRange(' in ctrl)
    ok("export تمرّر الفترة", 'from: r?.start,' in ctrl and 'to: r?.end,' in ctrl)
    ok("periodLabel تُبنى", 'String periodLabel(' in ctrl)
    ok("بيانات الـPDF تحمل period", "'period': periodLabel(st)," in ctrl)

    ok("الـPDF يقرأ period", "final period = '${data['period'] ?? ''}';" in pdf)
    ok("الـPDF يطبع سطر الفترة", "tx('الفترة: $period'" in pdf)

    # ─── الموضع: الملخّص **بعد** كل الجداول ───
    # ⚠️ نبحث عن **نصّ التسمية** لا عن صيغة السطر: التنسيق يتغيّر (وقد تغيّر
    # فعلًا عند لفّ الكتلة في pw.Row) فسقط الحرس زورًا. المهمّ الموضع لا الشكل.
    i_sum = pdf.find("'الملخّص'")
    i_last_table = pdf.find("sectionTitle('سجل استهلاك الاشتراك")
    ok("الملخّص موجود", i_sum > 0, i_sum)
    ok("جدول الاشتراك موجود", i_last_table > 0, i_last_table)
    ok("🚨 الملخّص **بعد** آخر جدول (نُقل للأسفل)",
       i_sum > i_last_table, f"الملخّص={i_sum} · آخر جدول={i_last_table}")
    ok("صافي الموقف داخل كتلة الملخّص السفلية",
       pdf.find("'صافي الموقف:'") > i_last_table)
    ok("عدد القطع داخل كتلة الملخّص السفلية",
       pdf.find("kv('عدد القطع:'") > i_last_table)

    # ─── التسمية: حذف كلمة «فواتير» ───
    ok("🚨 التسمية «عدد القطع:» بلا كلمة فواتير", "kv('عدد القطع:'" in pdf)
    ok("🚨 لا وجود لـ«عدد القطع (فواتير)» في الملف كله",
       'عدد القطع (فواتير)' not in pdf)

    # ─── الواجهة ───
    ok("ورقة الكشف تعرض الفترة", 'stmt.rangeLabel' in sheet)
    ok("منتقي المدى المخصّص", 'showDateRangePicker' in sheet)
    ok("إعدادات جاهزة: هذا الشهر", "'thisMonth'" in sheet)
    ok("إعدادات جاهزة: الشهر الماضي", "'lastMonth'" in sheet)
    ok("إعدادات جاهزة: كل الفترة", "'all'" in sheet)
    ok("الملخّص النصّي يحترم الفترة", 'from: r?.start,' in sheet)

    # ─── 🚨 حرس الانهيار: منتقي التاريخ بلا `locale` غير مدعوم ───
    # السبب الجذري (مُثبَت باختبار widget): التطبيق بلا `flutter_localizations`
    # ⇒ `_MaterialLocalizationsDelegate.isSupported` تقبل الإنجليزية فقط
    # (`locale.languageCode == 'en'`). و`showDateRangePicker(locale: ar)` يلفّ
    # الحوار بـ `Localizations.override(locale: ar)` فيفرض العربية **متجاوزًا**
    # حسم `MaterialApp` ⇒ `MaterialLocalizations.of(context)` ترجع `null`
    # (`Localizations.of<...>(...)!`) ⇒ في debug «No MaterialLocalizations
    # found» وفي release `!` على null = انهيار يوقف التطبيق.
    # أمّا `MaterialApp.locale` فيمرّ عبر `LocalizationsResolver` ويُحسم مقابل
    # `supportedLocales` ⇒ آمن ولا يشمله هذا الحرس (ولذلك نفحص وسائط المنتقي
    # فقط لا أي `locale:` في الملف).
    offenders = []
    lib_root = os.path.join(HERE, '..', 'lib')
    for root, _dirs, files in os.walk(lib_root):
        for fn in sorted(files):
            if not fn.endswith('.dart'):
                continue
            p = os.path.join(root, fn)
            src = strip_line_comments(open(p, encoding='utf-8').read())
            for call in picker_calls(src):
                if 'locale:' in call:
                    offenders.append(
                        f"{os.path.relpath(p, HERE)} → {call.splitlines()[0].strip()}")
    ok("🚨 لا يمرّر أي منتقي تاريخ `locale` غير مدعوم (يُنهي التطبيق)",
       not offenders, offenders[:3])

    print("\n" + "═" * 40)
    print(f"النتيجة الكلية: {PASS} نجحت · {FAIL} فشلت")
    if FAIL > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()
