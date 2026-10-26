#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات طبقة قاعدة جدول الخصومات (`discounts`) على SQLite حقيقي.

`tool/verify_tax_and_discount.dart` يُثبت **القواعد الخالصة** فقط (بلا قاعدة).
هذا الملف يُثبت ما لا يراه ذلك الاختبار: أن **نص SQL في `DiscountService`
يطابق فعلًا مخطط الجدول الحقيقي**، وأن الجدول **مضمون الوجود** على قاعدة قديمة.

يُثبت ثلاثة أمور:
  1. مخطط `discounts` متطابق حرفيًا في المواضع الثلاثة (`_onCreate` ·
     `_onUpgrade` · `runPendingMigrations`) — لا انحراف بين نسخة ونسخة.
  2. قاعدة قديمة **بلا** الجدول: الترحيل يُنشئه بالبنية الصحيحة (وكان الفشل
     صامتًا: `check` تبتلع الاستثناء، و`all()` ترجع قائمة فارغة).
  3. استعلامات الخدمة الثلاثة (البحث · الاستهلاك · إدارة) تعمل على المخطط
     الحقيقي بسلوكها المقصود.
"""
import os
import re
import sqlite3
import sys

PASS = 0
FAIL = 0

HERE = os.path.dirname(os.path.abspath(__file__))
SQLDB = os.path.join(HERE, '..', 'lib', 'sqldb.dart')

EXPECTED_COLUMNS = [
    # `name_en` جزء من المخطط الآن (دعم اللغتين) — تُكتب في المواضع الثلاثة.
    'discount_id', 'name', 'name_en', 'type', 'value', 'code',
    'start_date', 'end_date', 'is_active', 'max_uses', 'current_uses',
]


def check(label, got, want):
    global PASS, FAIL
    ok = got == want
    if ok:
        PASS += 1
        print(f"  PASS  {label}: {got}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got!r} expected {want!r}")


def ok(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS  {label}{(': ' + detail) if detail else ''}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}{(': ' + detail) if detail else ''}")


# ═══════════ 1) استخراج المخطط من sqldb.dart ═══════════

def extract_discount_ddl():
    """كل كتل `CREATE TABLE ... "discounts" (...)` في الملف."""
    with open(SQLDB, encoding='utf-8') as fh:
        src = fh.read()
    pattern = re.compile(
        r'CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+"discounts"\s*\((.*?)\)',
        re.DOTALL,
    )
    return [re.sub(r'\s+', ' ', m).strip() for m in pattern.findall(src)]


def normalized_columns(ddl):
    return re.findall(r'"(\w+)"', ddl)


print("=" * 62)
print("  إثبات طبقة قاعدة الخصومات — SQLite حقيقي")
print("=" * 62)

print("\n[1] وحدة المخطط: نسخة واحدة لا تنحرف")

ddls = extract_discount_ddl()
check("عدد مواضع تعريف الجدول (onCreate · onUpgrade · migration)", len(ddls), 3)

if len(ddls) == 3:
    ok("مخطط _onCreate == _onUpgrade", ddls[0] == ddls[1])
    ok("مخطط _onCreate == runPendingMigrations", ddls[0] == ddls[2])
    check("أسماء الأعمدة بالترتيب", normalized_columns(ddls[0]), EXPECTED_COLUMNS)
else:
    FAIL += 1
    print("  FAIL  تعذّر إتمام مقارنة المخطط (عدد غير متوقع)")

# ═══════════ 2) قاعدة قديمة بلا الجدول ═══════════

print("\n[2] قاعدة قديمة بلا `discounts` — الترحيل يُنشئه")

db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row
db.execute('CREATE TABLE "settings" ("key" TEXT PRIMARY KEY, "value" TEXT)')
db.execute('CREATE TABLE "invoices" ("invoices_id" INTEGER PRIMARY KEY, "final_amount" REAL)')
db.commit()

before = db.execute(
    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='discounts'"
).fetchone()[0]
check("قبل الترحيل: الجدول مفقود", before, 0)

# نفس نص الترحيل المُضاف في `runPendingMigrations`
if len(ddls) == 3:
    db.execute(f'CREATE TABLE IF NOT EXISTS "discounts" ({ddls[2]})')
    db.commit()

after = db.execute(
    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='discounts'"
).fetchone()[0]
check("بعد الترحيل: الجدول موجود", after, 1)

cols = [r[1] for r in db.execute('PRAGMA table_info("discounts")')]
check("أعمدة الجدول الفعلية", cols, EXPECTED_COLUMNS)

# الترحيل يُعيد التشغيل بلا ضرر (idempotent)
db.execute(f'CREATE TABLE IF NOT EXISTS "discounts" ({ddls[2]})')
db.commit()
check(
    "إعادة تشغيل الترحيل لا تُنشئ نسخة ثانية",
    db.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='discounts'"
    ).fetchone()[0],
    1,
)

# ═══════════ 3) البحث بالكود — نص الخدمة حرفيًا ═══════════

print("\n[3] البحث بالكود: تطبيع حالة الأحرف والفراغات")

db.execute(
    'INSERT INTO "discounts" (name, type, value, code, start_date, end_date, '
    'is_active, max_uses, current_uses) VALUES (?,?,?,?,?,?,?,?,?)',
    ('خصم الصيف', 'percentage', 10.0, 'SUMMER', '2026-01-01', None, 1, None, 0),
)
db.commit()

Q_CHECK = (
    'SELECT * FROM "discounts" WHERE UPPER(TRIM(code)) = UPPER(?) '
    'ORDER BY discount_id DESC LIMIT 1'
)


def find(code):
    rows = db.execute(Q_CHECK, (code.strip(),)).fetchall()
    return rows[0] if rows else None


ok("كود مطابق تمامًا يُوجد", find('SUMMER') is not None)
ok("حالة أحرف مختلفة تُطابق", find('summer') is not None)
ok("فراغات حول الكود تُطابق", find('  SuMmEr  ') is not None)
ok("كود غير موجود ⇒ لا نتيجة (لا استثناء)", find('NOPE') is None)

# ═══════════ 4) الاستهلاك — نص الخدمة حرفيًا ═══════════

print("\n[4] الاستهلاك: الزيادة من صفر ومن NULL")

Q_CONSUME = (
    'UPDATE "discounts" SET "current_uses" = COALESCE("current_uses", 0) + 1 '
    'WHERE "discount_id" = ?'
)

did = find('SUMMER')['discount_id']
db.execute(Q_CONSUME, (did,))
db.commit()
check(
    "بعد استهلاك واحد",
    db.execute('SELECT current_uses FROM "discounts" WHERE discount_id = ?', (did,)).fetchone()[0],
    1,
)

# صف قديم قد يكون عدّاده NULL فعلًا (العمود بلا NOT NULL)
db.execute('UPDATE "discounts" SET current_uses = NULL WHERE discount_id = ?', (did,))
db.commit()
db.execute(Q_CONSUME, (did,))
db.commit()
check(
    "من NULL ⇒ 1 (COALESCE يمنع NULL للأبد)",
    db.execute('SELECT current_uses FROM "discounts" WHERE discount_id = ?', (did,)).fetchone()[0],
    1,
)

# ═══════════ 5) الإدارة: التصفية · تضارب الكود · الحذف الناعم ═══════════

print("\n[5] الإدارة: التصفية وتضارب الأكواد والحذف الناعم")

db.execute(
    'INSERT INTO "discounts" (name, type, value, code, start_date, is_active, '
    'max_uses, current_uses) VALUES (?,?,?,?,?,?,?,?)',
    ('قديم', 'fixed', 5.0, 'OLD', '2025-01-01', 0, None, 0),
)
db.commit()

all_rows = db.execute('SELECT * FROM "discounts" ORDER BY discount_id DESC').fetchall()
check("كل الأكواد (بلا تصفية)", len(all_rows), 2)

active_rows = db.execute(
    'SELECT * FROM "discounts" WHERE COALESCE(is_active,0) = 1 ORDER BY discount_id DESC'
).fetchall()
check("النشِط فقط", len(active_rows), 1)
check("النشِط هو الصحيح", active_rows[0]['code'], 'SUMMER')

Q_CLASH = (
    'SELECT discount_id FROM "discounts" '
    'WHERE UPPER(TRIM(code)) = UPPER(?) AND discount_id != ?'
)
check(
    "إضافة كود جديد: لا تضارب (المقارنة بـ -1)",
    len(db.execute(Q_CLASH, ('NEWCODE', -1)).fetchall()),
    0,
)
check(
    "كود مكرّر بحالة أحرف مختلفة ⇒ تضارب مكتشَف",
    len(db.execute(Q_CLASH, ('summer', -1)).fetchall()),
    1,
)
check(
    "تعديل الصف على نفسه ⇒ لا تضارب مع ذاته",
    len(db.execute(Q_CLASH, ('summer', did)).fetchall()),
    0,
)

db.execute('UPDATE "discounts" SET is_active = 0 WHERE discount_id = ?', (did,))
db.commit()
check(
    "الحذف ناعم: الصف باقٍ",
    db.execute('SELECT COUNT(*) FROM "discounts" WHERE discount_id = ?', (did,)).fetchone()[0],
    1,
)
check(
    "الحذف ناعم: اختفى من النشِط",
    len(db.execute(
        'SELECT 1 FROM "discounts" WHERE COALESCE(is_active,0) = 1 AND discount_id = ?',
        (did,),
    ).fetchall()),
    0,
)

# ═══════════ 6) القواعد ترفض ما يُرجعه الاستعلام ═══════════

print("\n[6] التقاطع: صف موجود في القاعدة لكن القواعد ترفضه")

db.execute('UPDATE "discounts" SET is_active = 1 WHERE discount_id = ?', (did,))
db.commit()

row = find('SUMMER')
ok("الاستعلام يُرجعه (موجود فعلًا)", row is not None)

today = '2026-10-01'


def rules_accept(r, gross, today):
    """مرآة `DiscountRules.evaluate` — الشروط الحدّية شاملة ليومها."""
    if r is None:
        return False
    if not (r['code'] or '').strip():
        return False
    if int(r['is_active'] or 0) != 1:
        return False
    if r['start_date'] and today < r['start_date']:
        return False
    if r['end_date'] and today > r['end_date']:
        return False
    if r['max_uses'] is not None and int(r['current_uses'] or 0) >= int(r['max_uses']):
        return False
    if float(r['value'] or 0) <= 0 or gross <= 0:
        return False
    return True


ok("صف سليم ⇒ يُقبل", rules_accept(row, 200, today))

db.execute('UPDATE "discounts" SET end_date = ? WHERE discount_id = ?', ('2026-10-01', did))
db.commit()
ok("ينتهي اليوم ⇒ يبقى مقبولًا (شامل ليومه)", rules_accept(find('SUMMER'), 200, today))

db.execute('UPDATE "discounts" SET end_date = ? WHERE discount_id = ?', ('2026-09-30', did))
db.commit()
ok("انتهى أمس ⇒ مرفوض", not rules_accept(find('SUMMER'), 200, today))

db.execute(
    'UPDATE "discounts" SET end_date = NULL, max_uses = 1, current_uses = 1 '
    'WHERE discount_id = ?', (did,),
)
db.commit()
ok("نفدت الاستخدامات ⇒ مرفوض", not rules_accept(find('SUMMER'), 200, today))

db.execute(
    'UPDATE "discounts" SET max_uses = NULL, current_uses = 0, is_active = 0 '
    'WHERE discount_id = ?', (did,),
)
db.commit()
ok("معطَّل ⇒ مرفوض", not rules_accept(find('SUMMER'), 200, today))

db.close()

print("\n" + "=" * 62)
print(f"  النتيجة: {PASS} ناجح · {FAIL} فاشل")
print("=" * 62)
sys.exit(1 if FAIL else 0)
