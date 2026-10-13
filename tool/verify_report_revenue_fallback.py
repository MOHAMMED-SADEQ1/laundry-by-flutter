#!/usr/bin/env python3
"""اختبار انحدار دائم — إيراد الاشتراكات المُعترف به في التقارير.

يعزل الخطأ في `report_controller._recognizedSubRevenue`:

    final stored = SUM(subscription_used_value)؛
    if (stored > 0) return stored;          // ← الشرط على الإجمالي
    return DERIVED_FROM_list_data؛          // ← للمجموع كله

━━ الدلالة الحقيقية للعمودين ━━
`subscription_used_value` = **القيمة المستهلكة من رصيد الاشتراك المدفوع مقدمًا**.
`list_data.total_price`    = **سعر القائمة للخدمة المقدَّمة** (ما كانت ستُباع به).

عندما تكون الخدمة مغطّاة بالكامل داخل اشتراك مدفوع مسبقًا، تكون القيمة
المستهلكة من الرصيد = **صفر مشروع** (لا يُخصم من الاشتراك لأنه داخل السقف)،
بينما سعر القائمة يظل مرتفعًا.

━━ الخلل ━━
لأن الشرط على **الإجمالي** لا على الصف، فإن أي فترة يكون فيها مجموع العمود
صفرًا (أو أي فترة لا توجد فيها صفوف حديثة) تُسقِط القيمة المخزَّنة **للفترة
بأكملها** وتُرجع سعر القائمة بدلًا منها.

النتيجة: **الإيراد المعترف به يتضخّم إلى سعر القائمة للخدمة المجانية**،
وهو بالضبط ما كان يُقصَد منعاً عند إدخال محاسبة الاستحقاق.

السلوك الصحيح: `COALESCE` على **مستوى الصف** — يأخذ المخزَّن إن وُجد (حتى لو
صفرًا)، ويشتقّ فقط للصفوف القديمة التي لا تملك العمود.
"""
import sqlite3
import sys

FAILURES = []


def check(label, actual, expected):
    ok = abs(actual - expected) < 1e-9
    if not ok:
        FAILURES.append(label)
    print(f"  {'OK  ' if ok else 'FAIL'} {label}")
    if not ok:
        print(f"        الناتج: {actual}   المتوقّع: {expected}")


def build(rows):
    db = sqlite3.connect(":memory:")
    c = db.cursor()
    c.execute(
        """CREATE TABLE invoices (
               id INTEGER PRIMARY KEY,
               subscription_id INTEGER,
               subscription_used_value REAL,
               list_data TEXT,
               invoice_date TEXT)"""
    )
    c.executemany("INSERT INTO invoices VALUES (?,?,?,?,?)", rows)
    return c


def current_code(c, start, end):
    """ينسخ منطق report_controller._recognizedSubRevenue حرفيًا."""
    stored = c.execute(
        """SELECT COALESCE(SUM(subscription_used_value), 0) FROM invoices
           WHERE subscription_id IS NOT NULL
             AND DATE(invoice_date) >= ? AND DATE(invoice_date) <= ?""",
        (start, end),
    ).fetchone()[0]
    if stored > 0:
        return float(stored)
    # ← المسار الاحتياطي: يُستبدل به المجموع كله
    fallback = c.execute(
        """SELECT COALESCE(SUM(CAST(json_extract(j.value, '$.total_price') AS REAL)), 0)
           FROM invoices i, json_each(i.list_data) j
           WHERE i.subscription_id IS NOT NULL
             AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) <= ?""",
        (start, end),
    ).fetchone()[0]
    return float(fallback)


def fixed_code(c, start, end):
    """COALESCE على مستوى الصف — الصحيح."""
    return float(
        c.execute(
            """SELECT COALESCE(SUM(
                   COALESCE(subscription_used_value,
                            (SELECT SUM(CAST(json_extract(j.value, '$.total_price') AS REAL))
                             FROM json_each(i.list_data) j))), 0)
               FROM invoices i
               WHERE i.subscription_id IS NOT NULL
                 AND DATE(i.invoice_date) >= ? AND DATE(i.invoice_date) <= ?""",
            (start, end),
        ).fetchone()[0]
    )


def inv(i, sub, stored, price, day):
    return (i, sub, stored, '[{"total_price":%s}]' % price, "2026-09-%02d" % day)


S, E = "2026-09-01", "2026-09-30"

print("report_controller._recognizedSubRevenue — المسار الاحتياطي")
print("=" * 70)

# ── 1: استهلاك حقيقي خارج السقف (يُخصم من الرصيد) ────────────────────
print("\n[1] صف حديث: استهلك 60 من الرصيد، سعر القائمة 60")
c = build([inv(1, 7, 60.0, 60, 10), inv(2, 7, 60.0, 60, 11)])
check("الإيراد المعترف به = 120", current_code(c, S, E), 120.0)
check("والصحيح مطابق", fixed_code(c, S, E), 120.0)

# ── 2: صفر مشروع — الخدمة داخل التغطية المدفوعة مسبقًا ───────────────
print("\n[2] صف حديث: القيمة المستهلكة من الرصيد = 0 (مشروع)، سعر القائمة 80")
print("    ⟵ الدلالة: خدمة مجانية داخل الاشتراك. الإيراد المعترف به يجب أن يكون")
print("      هو المخزَّن (صفر المشروع)، لا سعر القائمة 80.")
c = build([inv(1, 7, 0.0, 80, 10)])
check("الصحيح = 0 (المخزَّن)", fixed_code(c, S, E), 0.0)
check("الحالي = 80 (سعر القائمة خطأً)", current_code(c, S, E), 80.0)

# ── 3: فترة مختلطة ───────────────────────────────────────────────────
print("\n[3] فترة مختلطة: صف حديث 0 (مشروع) + صف قديم NULL (اشتقاق 50)")
print("    ⟵ الصحيح = 0 + 50 = 50.")
c = build([inv(1, 7, 0.0, 80, 10), inv(2, 7, None, 50, 11)])
check("الصحيح = 50", fixed_code(c, S, E), 50.0)
check("الحالي = 130 (80+50 سعر القائمة خطأً)", current_code(c, S, E), 130.0)

# ── 4: لا صفوف حديثة إطلاقًا (نظام لم يُرحَّل) ────────────────────────
print("\n[4] كل الصفوف قديمة (NULL) — يجب أن يشتقّ الكل")
c = build([inv(1, 8, None, 45, 12), inv(2, 8, None, 15, 13)])
check("تطابق المسارين = 60", current_code(c, S, E), 60.0)
check("والصحيح أيضًا", fixed_code(c, S, E), 60.0)

# ── 5: تضخيم كبير — المخاطرة المالية ─────────────────────────────────
print("\n[5] الخطر المالي: 10 قطع استهلاك مجاني، سعر القائمة 500")
print("    ⟵ المخزَّن = 0 مشروع. الحالي يُبلّغ عن 500 إيرادًا وهميًا.")
c = build([inv(1, 9, 0.0, 500, 10)])
check("الصحيح = 0", fixed_code(c, S, E), 0.0)
check("الحالي = 500", current_code(c, S, E), 500.0)

# ── حارس انحدار ──────────────────────────────────────────────────────
print("\nحارس انحدار (يجب أن يظل الكود الحالي منحرفًا):")
c = build([inv(1, 9, 0.0, 250, 10)])
cur, fix = current_code(c, S, E), fixed_code(c, S, E)
dev = cur != fix
if not dev:
    FAILURES.append("حارس الانحدار")
print(f"  {'OK  ' if dev else 'FAIL'} منحرف (حالي={cur}، صحيح={fix})")

print("\n" + "=" * 70)
if FAILURES:
    print(f"RESULT: {len(FAILURES)} حالة فاشلة")
    for f in FAILURES:
        print(f"  - {f}")
    sys.exit(1)
print("RESULT: ALL CHECKS PASSED")
