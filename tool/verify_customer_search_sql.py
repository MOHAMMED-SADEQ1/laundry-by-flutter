#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
إثبات طبقة قاعدة البحث عن الزبائن على SQLite حقيقي.

`tool/verify_customer_search.dart` يُثبت **المنطق الخالص** فقط (بلا قاعدة).
هذا الملف يُثبت ما لا يراه ذلك الاختبار:

  1. شرط `where` المُولَّد يعمل فعلًا على **مخطط `customers` الحقيقي** المستخرج
     نصيًا من `lib/sqldb.dart` (لا انحراف بين الأعمدة المُستعملة والموجودة).
  2. المطابقة بالجوال تتجاوز اختلاف الفواصل **في الطرفين**: رقم مخزَّن
     `0509 999 999` يُطابقه بحث `0509999999` (فضلًا عن `REPLACE`).
  3. المطابقة بالأرقام العربية: `٠٥٥٥…` تجد الرقم المخزَّن لاتينيًا.
  4. الزبون المحذوف ناعمًا (`is_active = 0`) لا يظهر أبدًا.
  5. كل قيمة بمعامل `?` — فلا مدخل يُنفَّذ كـSQL.
"""
import os
import re
import sqlite3
import sys

PASS = 0
FAIL = 0

HERE = os.path.dirname(os.path.abspath(__file__))
SQLDB = os.path.join(HERE, '..', 'lib', 'sqldb.dart')
CONTROLLER = os.path.join(
    HERE, '..', 'lib', 'controller', 'customersnumbercontroller.dart'
)

# الأعمدة التي يستعملها شرط البحث — يجب أن تكون في المخطط الحقيقي.
NEEDED_COLUMNS = ['customer_name', 'phone_1', 'phone_2', 'is_active']

ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩'
EXTENDED_ARABIC = '۰۱۲۳۴۵۶۷۸۹'
PHONE_SEPARATORS = [' ', '-', '+', '(', ')']

# مرآة `CustomerSearch._phoneLike` (أرقام لاتينية/عربية وفواصل فقط).
PHONE_LIKE = re.compile(r'^[0-9\u0660-\u0669\u06f0-\u06f9+\-()\s]+$')


def check(label, got, want):
    global PASS, FAIL
    if got == want:
        PASS += 1
        print(f"  PASS  {label}: {got}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}: got {got!r} expected {want!r}")


def ok(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS  {label}{(': ' + str(detail)) if detail else ''}")
    else:
        FAIL += 1
        print(f"  FAIL  {label}{(': ' + str(detail)) if detail else ''}")


def strip_line_comments(src):
    """يُسقط تعليقات `//` كي لا يُحسب شرح الخطأ القديم كأنه الخطأ نفسه."""
    out = []
    for line in src.splitlines():
        idx = line.find('//')
        out.append(line if idx < 0 else line[:idx])
    return '\n'.join(out)


# ═══════════ مرآة دقيقة لدوال Dart في customer_search.dart ═══════════

def normalize(raw):
    return re.sub(r'\s+', ' ', raw.strip())


def to_western_digits(raw):
    out = []
    for ch in raw:
        if ch in ARABIC_INDIC:
            out.append(str(ARABIC_INDIC.index(ch)))
        elif ch in EXTENDED_ARABIC:
            out.append(str(EXTENDED_ARABIC.index(ch)))
        else:
            out.append(ch)
    return ''.join(out)


def phone_digits(raw):
    return re.sub(r'[^0-9]', '', to_western_digits(raw))


def looks_like_phone(normalized):
    """مرآة `CustomerSearch.looksLikePhone`."""
    return bool(normalized) and bool(PHONE_LIKE.match(normalized))


def phone_expression(column):
    expr = column
    for sep in PHONE_SEPARATORS:
        expr = f"REPLACE({expr}, '{sep}', '')"
    return expr


def build_query(query):
    """يعيد (where, args) بنفس ترتيب Dart حرفيًا."""
    norm = normalize(query)
    clauses = ['customer_name LIKE ?']
    args = [f'%{norm}%']
    exprs = [phone_expression('phone_1'), phone_expression('phone_2')]
    for expr in exprs:
        clauses.append(f'{expr} LIKE ?')
        args.append(f'%{norm}%')
    digits = phone_digits(norm) if looks_like_phone(norm) else ''
    if digits and digits != norm:
        for expr in exprs:
            clauses.append(f'{expr} LIKE ?')
            args.append(f'%{digits}%')
    return ' OR '.join(clauses), args


def extract_customers_ddl():
    with open(SQLDB, encoding='utf-8') as fh:
        src = fh.read()
    pattern = re.compile(
        r'CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+"customers"\s*\((.*?)\)',
        re.DOTALL,
    )
    return [re.sub(r'\s+', ' ', m).strip() for m in pattern.findall(src)]


print("=" * 62)
print("  إثبات طبقة قاعدة البحث عن الزبائن — SQLite حقيقي")
print("=" * 62)

print("\n[1] المخطط الحقيقي: الأعمدة المُستعملة موجودة فعلًا")

ddls = extract_customers_ddl()
if not ddls:
    print("  FAIL  لم يُعثر على تعريف جدول customers في sqldb.dart")
    sys.exit(1)
check("عدد مواضع تعريف جدول customers", len(ddls), 2)
ok("مخطط _onCreate == _onUpgrade", ddls[0] == ddls[1])

db = sqlite3.connect(':memory:')
db.row_factory = sqlite3.Row
db.execute(f'CREATE TABLE IF NOT EXISTS "customers" ({ddls[0]})')
db.commit()

columns = [r[1] for r in db.execute('PRAGMA table_info("customers")')]
for needed in NEEDED_COLUMNS:
    ok(f"العمود {needed} موجود في المخطط الفعلي", needed in columns)

# ═══════════ بيانات حقيقية تشمل كل صيغ التخزين ═══════════

db.executemany(
    'INSERT INTO "customers" (customer_id, customer_name, phone_1, phone_2, '
    'join_date, is_active) VALUES (?,?,?,?,?,?)',
    [
        (1, 'أحمد علي', '0555123456', None, '2026-01-01', 1),
        (2, 'سعيد محمد', '0509 999 999', None, '2026-01-02', 1),
        (3, 'خالد سعد', None, '0533000000', '2026-01-03', 1),
        (4, 'Ahmed Ali', '966555555555', None, '2026-01-04', 1),
        (5, 'زبون محذوف', '0555000000', None, '2026-01-05', 0),
        (6, 'نورة', '٠٥٩٩٩٩٩٩٩٩', None, '2026-01-06', 1),
    ],
)
db.commit()


def search(query, limit=25):
    where, args = build_query(query)
    sql = (
        'SELECT customer_id FROM "customers" '
        f'WHERE is_active = 1 AND ({where}) '
        'ORDER BY customer_name LIMIT ?'
    )
    return [r[0] for r in db.execute(sql, args + [limit])]


print("\n[2] البحث بالاسم")

check("اسم عربي كامل", search('أحمد'), [1])
check("جزء من الاسم", search('سعد'), [3])
check("إنجليزي بحروف صغيرة (LIKE بلا حساسية)", search('ahmed'), [4])
check("اسم غير موجود", search('زياد'), [])

print("\n[3] البحث بالجوال — كل صيغ التخزين")

check("رقم نظيف مخزَّن نظيفًا", search('0555123456'), [1])
check("بحث بمسافات يجد الرقم المتصل", search('0555 123 456'), [1])
check("بحث نظيف يجد الرقم المخزَّن بمسافات (REPLACE)", search('0509999999'), [2])
check("بحث بشرطات يجد الرقم المتصل", search('0555-123-456'), [1])
check("الرقم الثاني (phone_2)", search('53300'), [3])
check("بحث بأرقام عربية يجد الرقم اللاتيني", search('٠٥٥٥١٢٣٤٥٦'), [1])
check("بحث بأرقام عربية يجد الرقم العربي", search('٠٥٩٩٩٩٩٩٩٩'), [6])
check("جزء من الرقم", search('5123'), [1])

print("\n[4] الزبون المحذوف ناعمًا لا يظهر")

check("رقم الزبون غير النشط", search('0555000000'), [])
check("اسم الزبون غير النشط", search('زبون محذوف'), [])
total = db.execute('SELECT COUNT(*) FROM "customers"').fetchone()[0]
ok("الجدول يحتوي فعلًا على الزبون غير النشط", total == 6, f'الصفوف={total}')

print("\n[5] كل القيم بمعامل ? — لا مدخل يُنفَّذ كـSQL")

where, args = build_query('0555 123')
check("عدد ? يساوي عدد الوسائط", where.count('?'), len(args))
ok("لا رقم مدموج في نص الشرط", '0555' not in where)
ok(
    "ثوابت REPLACE فقط المُدمجة (5 × عمودين × صيغتين)",
    where.count('REPLACE(') == 20,
)

check("محاولة حقن لا تُطابق شيئًا", search("' OR 1=1 --"), [])
check("محاولة حقن باسم عمود", search("x' OR is_active = 0 --"), [])
check("محاولة حقن بعلامة اقتباس", search("' OR customer_name LIKE '%"), [])
check("رموز البدل % لا تُفشل البحث", sorted(search('%')), [1, 2, 3, 4, 6])

print("\n[5ب] حرس «يبدو رقمًا»: نص فيه حروف لا يُطابق الأرقام")

check("حرس: 'محمد 5' ليس رقمًا", looks_like_phone(normalize('محمد 5')), False)
check("حرس: '0555 123' رقم", looks_like_phone(normalize('0555 123')), True)
where_mixed, args_mixed = build_query('محمد 5')
check("عدد ? للنص المخلوط", where_mixed.count('?'), len(args_mixed))
ok("ثلاثة شروط فقط (لا صيغة أرقام)", where_mixed.count(' OR ') == 2)
check("'محمد 5' لا يُرجع زبائن بالأرقام وحدها", search('محمد 5'), [])

print("\n[6] الحد الأقصى للنتائج يُحترم")

check("حدّ 2 من نتائج عريضة", len(search('5', limit=2)), 2)

print("\n[7] المتحكم يفوّض للمنطق الخالص (لا نسخة ثانية)")

with open(CONTROLLER, encoding='utf-8') as fh:
    controller_src = fh.read()
ok(
    "يستدعي CustomerSearch.buildQuery",
    'CustomerSearch.buildQuery' in controller_src,
)
ok(
    "يستدعي CustomerSearch.normalize",
    'CustomerSearch.normalize' in controller_src,
)
ok(
    "يحرس النص الفارغ قبل القاعدة",
    'if (q.isEmpty) return <Map<String, dynamic>>[];' in controller_src,
)
ok(
    "searchSuggestions تُفوّض إلى searchByText",
    'searchByText(query, limit: 6)' in controller_src,
)

print("\n[8] حقل الفاتورة في الرئيسية (custominputname.dart)")

INVOICE_FIELD = os.path.join(
    HERE, '..', 'lib', 'view', 'widget', 'invoice', 'custominputname.dart'
)
with open(INVOICE_FIELD, encoding='utf-8') as fh:
    field_src = fh.read()
ok(
    "التلميح يذكر رقم الجوال",
    'رقم الجوال' in field_src,
)
ok(
    "يفوّض البحث إلى المتحكم (searchSuggestions)",
    'searchSuggestions(value)' in field_src,
)
ok(
    "يعرض الرقمين لا phone_1 وحده",
    "_phonesLabel(customer)" in field_src
    and "const ['phone_1', 'phone_2']" in field_src,
)
ok(
    "كشف الرقم يستعمل CustomerSearch (لا تعبير نمطي ضيّق)",
    'CustomerSearch.looksLikePhone' in field_src
    and 'CustomerSearch.phoneDigits' in field_src,
)
ok(
    "لا تعبير نمطي قديم يرفض الأرقام العربية",
    r"RegExp(r'^[0-9+\-\s]{6,}$')" not in field_src,
)

print("\n[9] تقرير أعمار الديون (نفس الفلتر لا نسخة أضعف)")

AGING_CONTROLLER = os.path.join(
    HERE, '..', 'lib', 'controller', 'customer', 'debt_report_controller.dart'
)
AGING_SERVICE = os.path.join(
    HERE, '..', 'lib', 'services', 'customer', 'debt_report_service.dart'
)
with open(AGING_CONTROLLER, encoding='utf-8') as fh:
    aging_ctrl_raw = fh.read()
with open(AGING_SERVICE, encoding='utf-8') as fh:
    aging_svc_src = fh.read()
# الشروط تفحص **الكود** لا التعليقات (وإلا مرّ شرح الخطأ القديم كأنه الخطأ نفسه).
aging_ctrl_src = strip_line_comments(aging_ctrl_raw)
ok(
    "الفلترة تمرّ عبر CustomerSearch.matches",
    'CustomerSearch.matches(r.toSearchMap(), q)' in aging_ctrl_src,
)
ok(
    "لا مطابقة حرفية قديمة على رقم واحد",
    'r.phone.contains(q)' not in aging_ctrl_src,
)
ok(
    "الصف يحمل الرقمين للبحث",
    "final String phone2;" in aging_svc_src
    and "'phone_2': phone2" in aging_svc_src,
)
ok(
    "الرقم الثاني يُقرأ من القاعدة فعلًا",
    "phone2: _pickPhones(r).secondary" in aging_svc_src,
)

print("\n" + "═" * 40)
print(f"النتيجة: {PASS} نجحت · {FAIL} فشلت")
if FAIL > 0:
    sys.exit(1)